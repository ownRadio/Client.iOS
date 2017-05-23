//
//  Downloader.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 12/5/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//
//	Download track in cache

import Foundation

class Downloader {
	
	static let sharedInstance = Downloader()
//	var taskQueue: OperationQueue?
	let baseURL = URL(string: "http://api.ownradio.ru/v3/tracks/")
	let applicationSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
	let tracksPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Tracks/")
	let tracksUrlString =  FileManager.applicationSupportDir().appending("/Tracks/")
	
	let limitMemory =  UInt64(DiskStatus.freeDiskSpaceInBytes / 2)
	
	var requestCount = 0;
	var completionHandler:(()->Void)? = nil
	
	func load(complition: @escaping (() -> Void)) {

		//проверяем свободное место, если его достаточно - загружаем треки
			if DiskStatus.folderSize(folderPath: tracksUrlString) < limitMemory  {
				//получаем trackId следующего трека и информацию о нем
				self.completionHandler = complition
				ApiService.shared.getTrackIDFromServer { [unowned self] (dict) in
					guard dict["id"] != nil else {
						return
					}
					print(dict["id"])
					let trackURL = self.baseURL?.appendingPathComponent(dict["id"] as! String)
					if let audioUrl = trackURL {
						//задаем директорию для сохранения трека
						let destinationUrl = self.tracksPath.appendingPathComponent(audioUrl.lastPathComponent)
							//если этот трек не еще не загружен - загружаем трек
//						let mp3Path = destinationUrl.appendingPathExtension("mp3")
						guard FileManager.default.fileExists(atPath: destinationUrl.path ) == false else {
							self.createPostNotificationSysInfo(message: "File already exist and won't load")
							return
						}
							//используется замыкание для сохранения загруженного трека в файл и информации о треке в бд
							let downloadRequest = self.createDownloadTask(audioUrl: audioUrl, destinationUrl: destinationUrl, dict: dict)
						
								downloadRequest.resume()
						
//						}
					}
				}
				
		} else {
			// если память заполнена удаляем трек
				if self.requestCount < 2 {
					if self.completionHandler != nil {
						self.completionHandler!()
					}
					self.requestCount += 1
					deleteOldTrack()
					
					
					self.load {
						
					}
				
				}else {
					self.requestCount = 0
				}

		}
	}

	func createDownloadTask(audioUrl:URL, destinationUrl:URL, dict:[String:AnyObject]) -> URLSessionDownloadTask {
		return URLSession.shared.downloadTask(with: audioUrl, completionHandler: { (location, response, error) -> Void in
			guard error == nil else {
				self.createPostNotificationSysInfo(message: error.debugDescription)
				return
			}
			guard let newLocation = location, error == nil else {return }
			
			do {
				let file = NSData(contentsOf: newLocation)
				let mp3Path = destinationUrl.appendingPathExtension("mp3")
				guard FileManager.default.fileExists(atPath: mp3Path.path ) == false else {
					self.createPostNotificationSysInfo(message: "MP3 file exist")
					return
				}
				
				//сохраняем трек
				//задаем конечных путь хранения файла (добавляем расширение)
				let endPath = destinationUrl.appendingPathExtension("mp3")
				try file?.write(to: endPath, options:.noFileProtection)
				
				//сохраняем информацию о файле в базу данных
				
				guard FileManager.default.fileExists(atPath: mp3Path.absoluteString ) == false else {
					self.createPostNotificationSysInfo(message: "MP3 file exist")
					return
				}
				
				let trackEntity = TrackEntity()
				
				trackEntity.path = String(describing: endPath.lastPathComponent)
				trackEntity.countPlay = 0
				trackEntity.artistName = dict["artist"] as? String
				trackEntity.trackName = dict["name"] as? String
				trackEntity.trackLength = NSString(string: dict["length"] as! String).doubleValue
				trackEntity.recId = dict["id"] as! String?
				trackEntity.playingDate = NSDate.init(timeIntervalSinceNow: -315360000.0042889)
				
				CoreDataManager.instance.saveContext()
				
				if self.requestCount < 2 {
					if self.completionHandler != nil {
						self.completionHandler!()
					}
						self.load(complition: self.completionHandler!)
					self.requestCount += 1
					} else {
						if self.completionHandler != nil {
							self.completionHandler!()
						}
						self.requestCount = 0
				}
				
//				complition()
				self.createPostNotificationSysInfo(message: "File moved to documents folder")
				print("File moved to documents folder")
			} catch let error as NSError {
				print(error.localizedDescription)
			}
		})
	}
	
	func createPostNotificationSysInfo (message:String) {
		NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":message])
	}
	
	// удаление трека если память заполнена
	func deleteOldTrack () {
		// получаем трек проиграный большее кол-во раз
		let song: SongObject? = CoreDataManager.instance.getOldTrack()
		// получаем путь файла
		guard song != nil else {
			return
		}
		let path = self.tracksUrlString.appending((song?.path!)!)
		if FileManager.default.fileExists(atPath: path) {
			do{
				// удаляем обьект по пути
				try FileManager.default.removeItem(atPath: path)
				self.createPostNotificationSysInfo(message: "File was delete")
			}
			catch {
				print("Error with remove file ")
			}
			// удаляем трек с базы
//			CoreDataManager.instance.managedObjectContext.performAndWait {
				CoreDataManager.instance.deleteTrackFor(trackID: (song?.trackID)!)
				CoreDataManager.instance.saveContext()
//			}
			
		}
	}
	
}
