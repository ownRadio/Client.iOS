//
//  Downloader.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 12/5/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//

import Foundation
class Downloader {
	class func load(completion: @escaping () -> ()) {
		
		let baseURL = URL(string: "http://api.ownradio.ru/v3/tracks/")
			
			ApiService.shared.getTrackIDFromServer { (dict) in
				let trackURL = baseURL?.appendingPathComponent(dict["id"] as! String)
				
				if let audioUrl = trackURL {
					
					let documentsDirectoryURL =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
					
					let destinationUrl = documentsDirectoryURL.appendingPathComponent(audioUrl.lastPathComponent)
					
					
					if FileManager.default.fileExists(atPath: destinationUrl.path) {
						print("The file already exists at path")
						
					} else {
						
						URLSession.shared.downloadTask(with: audioUrl, completionHandler: { (location, response, error) -> Void in
							guard let location = location, error == nil else { return }
							do {
								
//								try FileManager.default.moveItem(at: location, to: destinationUrl)
								
								let file = NSData(contentsOf: location)
								
								try file?.write(to: destinationUrl, options:.noFileProtection)
								let endPath = destinationUrl.appendingPathExtension("mp3")
								try FileManager.default.moveItem(at: destinationUrl, to: endPath)
								
								let trackEntity = TrackEntity()

								trackEntity.path = String(describing: endPath.lastPathComponent)
								trackEntity.countPlay = 0
								trackEntity.artistName = dict["artist"] as? String
								trackEntity.trackName = dict["name"] as? String
								trackEntity.trackLength = NSString(string: dict["length"] as! String).doubleValue
								trackEntity.recId = dict["id"] as! String?
								
								CoreDataManager.instance.saveContext()
								
								print("File moved to documents folder")
									
							} catch let error as NSError {
								print(error.localizedDescription)
							}
						}).resume()
					}
				}
				self.load(completion: { 
					
				})
			}
		}
		
	
	
//	class func load(to localUrl: URL, completion: @escaping () -> ()) {
//		let sessionConfig = URLSessionConfiguration.default
//		let session = URLSession(configuration: sessionConfig)
//		let tracksUrl = URL(string: "http://api.ownradio.ru/v3/tracks/")
//		let trackurl = tracksUrl?.appendingPathComponent((UserDefaults.standard.object(forKey: "UUIDDevice") as! String)).appendingPathComponent("/next")
//		
//		guard let url = trackurl else {
//			print("Error: cannot create URL")
//			return
//		}
//		let request = try! URLRequest(url: url)
//		
//		let task = session.downloadTask(with: request) { (tempLocalUrl, response, error) in
//			if let tempLocalUrl = tempLocalUrl, error == nil {
//				// Success
//				if let statusCode = (response as? HTTPURLResponse)?.statusCode {
//					print("Success: \(statusCode)")
//				}
//				
//				do {
//					try FileManager.default.copyItem(at: tempLocalUrl, to: localUrl)
//					completion()
//				} catch (let writeError) {
//					print("error writing file \(localUrl) : \(writeError)")
//				}
//				
//			} else {
//				print("Failure: %@", error?.localizedDescription);
//			}
//		}
//		task.resume()
//	}
}
