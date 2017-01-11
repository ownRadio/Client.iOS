//
//  CoreDataManager.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 12/1/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//
//	Data Manager, creation and managing with data

import CoreData
import Foundation

class CoreDataManager {
	
	// Singleton
	static let instance = CoreDataManager()
	
	private init() {}
	
	// Entity for Name
	func entityForName(entityName: String) -> NSEntityDescription {
		return NSEntityDescription.entity(forEntityName: entityName, in: self.managedObjectContext)!
	}
	
	func getAllEntitiesFor(entityName:String) -> [Any] {
		let request:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName:entityName)
		var fetchRequest = [Any]()
		do {
			fetchRequest = try self.managedObjectContext.fetch(request)
		} catch {
			fatalError("Failed to fetch : \(error)")
		}
		return fetchRequest
	}
	
	// MARK: - Core Data stack
	
	lazy var applicationDocumentsDirectory: NSURL = {
		let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
		return urls[urls.count-1] as NSURL
	}()
	
	lazy var managedObjectModel: NSManagedObjectModel = {
		let modelURL = Bundle.main.url(forResource: "DataModel", withExtension: "momd")!
		return NSManagedObjectModel(contentsOf: modelURL)!
	}()
	
	lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
		let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
		let url = self.applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")
		var failureReason = "There was an error creating or loading the application's saved data."
		do {
			let options = [NSMigratePersistentStoresAutomaticallyOption:true, NSInferMappingModelAutomaticallyOption:true]
			try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
		} catch {
			var dict = [String: AnyObject]()
			dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject?
			dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject?
			dict[NSUnderlyingErrorKey] = error as NSError
			let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
			NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
			abort()
		}
		return coordinator
	}()
	
	lazy var managedObjectContext: NSManagedObjectContext = {
		let coordinator = self.persistentStoreCoordinator
		var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
		managedObjectContext.persistentStoreCoordinator = coordinator
		return managedObjectContext
	}()
	
	// возвращает количество записей в таблице
	func chekCountOfEntitiesFor(entityName:String) -> Int {
		let request:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName:entityName)
		var count = 0
		do{
			count = try self.managedObjectContext.count(for: request)
			

		}catch {
			print("Error with get count of entities")
		}
		
		return count
	}
	
	// удаляет историю прослушивания трека с заданным trackId
	func deleteHistoryFor(trackID:String) {
		let fetchRequest: NSFetchRequest<HistoryEntity> = HistoryEntity.fetchRequest()
//		fetchRequest.predicate = NSPredicate(format: "trackId = %@", trackID)
		if let result = try? self.managedObjectContext.fetch(fetchRequest) {
			for object in result {
				self.managedObjectContext.delete(object)
			}
		}
	}
	
	// удаляет из базы трек с заданным trackId
	func deleteTrackFor(trackID:String) {
		let fetchRequest: NSFetchRequest<TrackEntity> = TrackEntity.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "recId = %@", trackID)
		if let result = try? self.managedObjectContext.fetch(fetchRequest) {
			for object in result {
				self.managedObjectContext.delete(object)
			}
		}
	}
	
	// задает текущую дату для трека с заданным trackId
	func setDateForTrackBy(trackId:String) {
		let fetchRequest: NSFetchRequest<TrackEntity> = TrackEntity.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "recId = %@", trackId)
		if let result = try? self.managedObjectContext.fetch(fetchRequest) {
			for object in result {
				object.playingDate = NSDate()
			}
		}
	}
	
	func sentHistory () {
		// если нет неотправленной истории прослушивания - выходим из функции
		guard CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "HistoryEntity") > 0 else {
			return
		}
		//create a fetch request, telling it about the entity
		let fetchRequest: NSFetchRequest<HistoryEntity> = HistoryEntity.fetchRequest()
		
		do {
			
			let searchResults = try self.managedObjectContext.fetch(fetchRequest)
			for track in searchResults {
				
				ApiService.shared.saveHistory(trackId: track.trackId!, isListen: Int(track.isListen))
				
				print("\(track.value(forKey: "trackId"))")
			}
		} catch {
			print("Error with request: \(error)")
		}
	}
	
	//выбираем из трек для проигрывания
	func getRandomTrack() -> SongObject {
		//задаем сортировку по возрастанию даты проигрывания
		let sectionSortDescriptor = NSSortDescriptor(key: "playingDate", ascending: true)
		let sortDescriptors = [sectionSortDescriptor]
		
		let fetchRequest: NSFetchRequest<TrackEntity> = TrackEntity.fetchRequest()
		fetchRequest.sortDescriptors = sortDescriptors
		let  song = SongObject()
		do {
			//выполняем запрос к БД
			let searchResults = try self.managedObjectContext.fetch(fetchRequest)
			//если в таблице нет записей - возращаем пустой объект song
			guard searchResults.count != 0 else {
				return song
			}
			//выбираем первую запись
			let track = searchResults.first
			
			song.name = track?.trackName
			song.artistName = track?.artistName
			song.trackLength = track?.trackLength
			song.trackID = track?.recId
			song.path = track?.path
			
		} catch {
			print("Error with request: \(error)")
		}
		return song
	}
	
	func getCountOfTracks() -> Int {
		
		let fetchRequest: NSFetchRequest<TrackEntity> = TrackEntity.fetchRequest()
		var count = 0
		do {
			//go get the results
			
			let searchResults = try self.managedObjectContext.fetch(fetchRequest)
			count = searchResults.count
		} catch {
			print("Error with request: \(error)")
		}
		return count
	}
	
	// MARK: - Core Data Saving support
	func saveContext () {
		if managedObjectContext.hasChanges {
			do {
				try managedObjectContext.save()
			} catch {
				let nserror = error as NSError
				NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
				abort()
			}
		}
	}
	
}
