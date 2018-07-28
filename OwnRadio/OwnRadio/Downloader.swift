//
//  Downloader.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 12/5/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//
//	Download track in cache

import Foundation
import UIKit

class Downloader {
	
	static let sharedInstance = Downloader()
	//	var taskQueue: OperationQueue?
	let baseURL = URL(string: "http://api.ownradio.ru/v5/tracks/")
	let applicationSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
	let tracksPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Tracks/")
	let tracksUrlString =  FileManager.applicationSupportDir().appending("/Tracks/")
	
	let limitMemory =  UInt64(DiskStatus.freeDiskSpaceInBytes / 2)
	var maxMemory = UInt64(1000000000)
	
	var requestCount = 0;
	var completionHandler:(()->Void)? = nil
	
	func load(complition: @escaping (() -> Void)) {

		if limitMemory < 1000000000 * (UserDefaults.standard.object(forKey: "maxMemorySize") as? UInt64)! {
			maxMemory = limitMemory
		} else {
			maxMemory = 1000000000 * (UserDefaults.standard.object(forKey: "maxMemorySize") as? UInt64)!
		}
		//проверяем свободное место, если его достаточно - загружаем треки
		if DiskStatus.folderSize(folderPath: tracksUrlString) < maxMemory  {
			//получаем trackId следующего трека и информацию о нем
			self.completionHandler = complition
			ApiService.shared.getTrackIDFromServer { [unowned self] (dict) in
				guard dict["id"] != nil else {
					return
				}
				print(dict["id"])
				let trackURL = self.baseURL?.appendingPathComponent(dict["id"] as! String).appendingPathComponent((UIDevice.current.identifierForVendor?.uuidString.lowercased())!)
				if let audioUrl = trackURL {
					//задаем директорию для сохранения трека
					let destinationUrl = self.tracksPath.appendingPathComponent(dict["id"] as! String)
					//если этот трек не еще не загружен - загружаем трек
					//						let mp3Path = destinationUrl.appendingPathExtension("mp3")
					guard FileManager.default.fileExists(atPath: destinationUrl.path ) == false else {
						self.createPostNotificationSysInfo(message: "File already exist and won't load")
						return
					}
					//добавляем трек в очередь загрузки
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
			
			if let httpResponse = response as? HTTPURLResponse {
				if httpResponse.statusCode == 200 {
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
						
						//Проверяем, полностью ли скачан трек
						if let contentLength = Int(httpResponse.allHeaderFields["Content-Length"] as! String) {
							if file!.length != contentLength || file!.length == 0 {
								if FileManager.default.fileExists(atPath: mp3Path.path) {
									do{
										// удаляем обьект по пути
										try FileManager.default.removeItem(atPath: mp3Path.path)
										self.createPostNotificationSysInfo(message: "Файл с длиной = \(file!.length), ContentLength = \(contentLength) удален")
									}
									catch {
										print("Ошибка при удалении недокачанного трека")
									}
								}
								return
							}
						}
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
//						trackEntity.isCorrect = 1
						
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
				}
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
		guard song != nil && song?.trackID != nil else {
			return
		}
		let path = self.tracksUrlString.appending((song?.path)!)
		print("Удаляем \(song!.trackID)")
		self.createPostNotificationSysInfo(message: "Удаляем \(song!.trackID.description)")
		if FileManager.default.fileExists(atPath: path) {
			do{
				// удаляем обьект по пути
				try FileManager.default.removeItem(atPath: path)
				self.createPostNotificationSysInfo(message: "File was delete")
			}
			catch {
				print("Deletion of file failed. Abort with error: \(error)")
				self.createPostNotificationSysInfo(message: "Deletion of file failed. Abort with error: \(error)")
			}
		}
			// удаляем трек с базы
			//			CoreDataManager.instance.managedObjectContext.performAndWait {
			CoreDataManager.instance.deleteTrackFor(trackID: (song?.trackID)!)
			CoreDataManager.instance.saveContext()
			//			}
			
//		} else {
//			CoreDataManager.instance.deleteTrackFor(trackID: song!.trackID)
//			CoreDataManager.instance.saveContext()
//			self.createPostNotificationSysInfo(message: "Трек был удален ранее. Удалена запись о треке")
//		}
	}
	
	func fillCache () {
		let limitMemory =  UInt64(DiskStatus.freeDiskSpaceInBytes / 2)
		let maxMemory = 1000000000 * (UserDefaults.standard.object(forKey: "maxMemorySize") as? UInt64)!
		let folderSize = DiskStatus.folderSize(folderPath: tracksUrlString)
		
		if folderSize < limitMemory && folderSize < maxMemory  {
			self.load {
				
				self.fillCache()
			}
		}
	}
	
}
