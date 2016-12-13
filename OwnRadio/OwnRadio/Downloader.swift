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
		
		var index = 0
		while index < 3 {
			if DiskStatus.folderSize(folderPath: FileManager.documentsDir()) <= (DiskStatus.freeDiskSpaceInBytes / 2)  {
				
				if DiskStatus.folderSize(folderPath: FileManager.documentsDir()) == 32800000000 {
					print("MEMORY MAX ")
				}
				
				ApiService.shared.getTrackIDFromServer { (dict) in
					guard dict["id"] != nil else {
						return
					}
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
									trackEntity.playingDate = NSDate.init(timeIntervalSince1970: 0)
									
									CoreDataManager.instance.saveContext()
									
									print("File moved to documents folder")
									
								} catch let error as NSError {
									print(error.localizedDescription)
								}
							}).resume()
						}
					}
				}
				index += 1
			}
		}
	}
}
