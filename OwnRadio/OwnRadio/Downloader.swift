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
	var taskQueue: OperationQueue?
	let baseURL = URL(string: "http://api.ownradio.ru/v3/tracks/")
	let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
	let tracksPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Tracks/")
	let tracksUrlString =  FileManager.documentsDir().appending("/Tracks/")
	
	func load() {

		//проверяем свободное место, если его достаточно - загружаем треки
		if DiskStatus.folderSize(folderPath: FileManager.documentsDir()) <= (DiskStatus.freeDiskSpaceInBytes / 2)  {
				//получаем trackId следующего трека и информацию о нем
				ApiService.shared.getTrackIDFromServer { (dict) in
					guard dict["id"] != nil else {
						return
					}
					let trackURL = self.baseURL?.appendingPathComponent(dict["id"] as! String)
					if let audioUrl = trackURL {
						//задаем директорию для сохранения трека
						let destinationUrl = self.tracksPath.appendingPathComponent(audioUrl.lastPathComponent)
						
						//проверяем, существует ли в директории файл с таким GUID'ом
						if FileManager.default.fileExists(atPath: destinationUrl.path) {
							NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"The file already exists at path"])
							print("The file already exists at path")
						} else {
							//если этот трек не еще не загружен - загружаем трек
							//используется замыкание для сохранения загруженного трека в файл и информации о треке в бд
							URLSession.shared.downloadTask(with: audioUrl, completionHandler: { (location, response, error) -> Void in
								guard let location = location, error == nil else { return }
								do {
									let file = NSData(contentsOf: location)
									let mp3Path = destinationUrl.appendingPathExtension("mp3")
									guard FileManager.default.fileExists(atPath: mp3Path.absoluteString ) == false else {
										NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"MP3 file exist"])
										print("MP3 file exist")
										return
									}
									//сохраняем трек
									try file?.write(to: destinationUrl, options:.noFileProtection)
									//задаем конечных путь хранения файла (добавляем расширение)
									let endPath = destinationUrl.appendingPathExtension("mp3")
									//перемещаем файл по заданному пути
									try FileManager.default.moveItem(at: destinationUrl, to: endPath)
									//сохраняем информацию о файле в базу данных
									let trackEntity = TrackEntity()
									
									trackEntity.path = String(describing: endPath.lastPathComponent)
									trackEntity.countPlay = 0
									trackEntity.artistName = dict["artist"] as? String
									trackEntity.trackName = dict["name"] as? String
									trackEntity.trackLength = NSString(string: dict["length"] as! String).doubleValue
									trackEntity.recId = dict["id"] as! String?
									trackEntity.playingDate = NSDate.init(timeIntervalSince1970: 0)
									
									CoreDataManager.instance.saveContext()
									NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"File moved to documents folder"])
									print("File moved to documents folder")
									
								} catch let error as NSError {
									print(error.localizedDescription)
								}
							}).resume()
						}
					}
				}
		} else {
			// если память заполнена удаляем трек 
			deleteOldTrack()
		}
	}
	
	// удаление трека если память заполнена
	func deleteOldTrack () {
		// получаем трек проиграный большее кол-во раз
		let song = CoreDataManager.instance.getOldTrack()
		// получаем путь файла
		let path = self.tracksUrlString.appending(song.path!)
		if FileManager.default.fileExists(atPath: path) {
			do{
				// удаляем обьект по пути
				try FileManager.default.removeItem(atPath: path)
			}
			catch {
				print("Error with remove file ")
			}
			// удаляем трек с базы
			CoreDataManager.instance.deleteTrackFor(trackID: song.trackID)
			CoreDataManager.instance.saveContext()
		}
		// пытаемся опять загрузить трек
		load()
	}
	
	// создание очереди
	func addTaskToQueue () {
//		проверка на существование очереди
		if self.taskQueue == nil {
			self.taskQueue = OperationQueue()
		}
//		задаем единственную операцию в один момент времени
		self.taskQueue?.maxConcurrentOperationCount = 1
		for _ in 0..<3 {
			
			self.taskQueue?.addOperation { [unowned self] in
				self.load()
			}
		}
	}

}
