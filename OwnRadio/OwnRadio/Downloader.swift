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
	
    var loadCallCount = 0;
    var successCount = 0
    
	func load(complition: @escaping (() -> Void)) {

		//проверяем свободное место, если его достаточно - загружаем треки
		if DiskStatus.folderSize(folderPath: tracksUrlString) <= (DiskStatus.freeDiskSpaceInBytes / 2)  {
				//получаем trackId следующего трека и информацию о нем
				ApiService.shared.getTrackIDFromServer { [unowned self] (dict) in
					guard dict["id"] != nil else {
						return
					}
                    if self.successCount < 3 {
                        self.successCount += 1
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
							let downloadRequest = URLSession.shared.downloadTask(with: audioUrl, completionHandler: { [unowned self] (location, response, error) -> Void in
								guard error == nil else {
									NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":error.debugDescription])
									return
								}
								guard let location = location, error == nil else {return }
								
								
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
									
									complition()
                                    if self.loadCallCount >= 3 && self.successCount >= 1 && self.successCount < 3 {
                                        self.load {
                                            complition()
                                        }
                                    }
									NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"File moved to documents folder"])
									print("File moved to documents folder")
								} catch let error as NSError {
									print(error.localizedDescription)
								}
							})
							self.taskQueue?.addOperation {
								downloadRequest.resume()
							}
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
			}
			catch {
				print("Error with remove file ")
			}
			// удаляем трек с базы
			CoreDataManager.instance.deleteTrackFor(trackID: (song?.trackID)!)
			CoreDataManager.instance.saveContext()
		}
	}
	
	// создание очереди
	func addTaskToQueueWith (complition: @escaping (() -> Void)) {
//		проверка на существование очереди
		if self.taskQueue == nil {
			self.taskQueue = OperationQueue()
		}
//		задаем единственную операцию в один момент времени
		self.taskQueue?.maxConcurrentOperationCount = 1
		for _ in 0..<3 {
            self.load(complition: complition)
            if loadCallCount < 3 {
                loadCallCount += 1
            }
		}
	}

}
