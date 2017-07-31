//
//  SettingsViewController.swift
//  OwnRadio
//
//  Created by Alexandra Polunina on 26.07.17.
//  Copyright © 2017 Netvox Lab. All rights reserved.
//

import UIKit
import Foundation

class SettingsViewController: UITableViewController {
	
	@IBOutlet weak var maxMemoryLbl: UILabel!
	@IBOutlet weak var stepper: UIStepper!
	@IBOutlet weak var onlyWiFiSwitch: UISwitch!
	@IBOutlet weak var freeSpaceLbl: UILabel!
	@IBOutlet weak var cacheFolderSize: UILabel!
	@IBOutlet weak var listenTracksSize: UILabel!
	@IBOutlet weak var delAllTracksLbl: UILabel!

	@IBOutlet weak var delAllTracksCell: UITableViewCell!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		let userDefaults = UserDefaults.standard
		let tracksUrlString = FileManager.applicationSupportDir().appending("/Tracks/")

		onlyWiFiSwitch.isOn = (userDefaults.object(forKey: "isOnlyWiFi") as? Bool)!
		
		stepper.wraps = true
		stepper.autorepeat = true
		stepper.value = (userDefaults.object(forKey: "maxMemorySize") as? Double)!
		
		stepper.minimumValue = 1.0
		stepper.maximumValue = 64.0
		maxMemoryLbl.text = (userDefaults.object(forKey: "maxMemorySize") as? Int)!.description  + " Gb"
		
		freeSpaceLbl.text = "Свободно " + DiskStatus.GBFormatter(Int64(DiskStatus.freeDiskSpaceInBytes)) + " Gb"
		
		cacheFolderSize.text = "Занято всего " + DiskStatus.GBFormatter(Int64(DiskStatus.folderSize(folderPath: tracksUrlString))) + " Gb (" + CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "TrackEntity").description + " треков)"
		
		let listenTracks = CoreDataManager.instance.getListenTracks()
		listenTracksSize.text = "Из них уже прослушанных " + DiskStatus.GBFormatter(Int64(DiskStatus.listenTracksSize(folderPath:tracksUrlString, tracks: listenTracks))) + " Gb (" + listenTracks.count.description + " треков)"
		
		let tapDelAllTracks = UITapGestureRecognizer(target: self, action: #selector(self.tapDelAllTracks(sender:)))
		delAllTracksCell.isUserInteractionEnabled =  true
		delAllTracksCell.addGestureRecognizer(tapDelAllTracks)
		
	}
	
	@IBAction func onlyWiFiSwitchValueChanged(_ sender: UISwitch) {
		UserDefaults.standard.set(onlyWiFiSwitch.isOn, forKey: "isOnlyWiFi")
	}
	
	//Сохраняем настроки "занимать не более" и выводим актуальное значение при его изменении
	@IBAction func stepperValueChanged(_ sender: UIStepper) {
		maxMemoryLbl.text = Int(stepper.value).description + " Gb"
		UserDefaults.standard.set(stepper.value, forKey: "maxMemorySize")
		
	}
	
	
	@IBAction func btnfillCacheClick(_ sender: UIButton) {
		guard currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable else {
			return
		}
		
		DispatchQueue.global(qos: .background).async {
			Downloader.sharedInstance.fillCache()
		}
	}
	
	func tapDelAllTracks(sender: UITapGestureRecognizer) {
		
		let tracksUrlString = FileManager.applicationSupportDir().appending("/Tracks/")
		// получаем содержимое папки Tracks
		if let tracksContents = try? FileManager.default.contentsOfDirectory(atPath: tracksUrlString ){
		
			for track in tracksContents {
				// проверка для удаления только треков
				if track.contains("mp3") {
					let path = tracksUrlString.appending(track)
					do{
						print(path)
						try FileManager.default.removeItem(atPath: path)
						
					} catch  {
						print("Ошибка при удалении файла  - \(error)")
					}
				}
			}

		//удаляем треки из базы
		CoreDataManager.instance.deleteAllTracks()
			
		viewDidLoad()
		}
	}
	
	@IBAction func delListenTracksBtn(_ sender: UIButton) {
		let tracksUrlString =  FileManager.applicationSupportDir().appending("/Tracks/")
		
		let listenTracks = CoreDataManager.instance.getListenTracks()
		print("\(listenTracks.count)")
		for _track in listenTracks {
			let path = tracksUrlString.appending((_track.path!))
			
			if FileManager.default.fileExists(atPath: path) {
				do{
					// удаляем файл
					try FileManager.default.removeItem(atPath: path)
				}
				catch {
					print("Ошибка при удалении файла - \(error)")
				}
			}
			// удаляем трек с базы
			CoreDataManager.instance.deleteTrackFor(trackID: _track.trackID)
			CoreDataManager.instance.saveContext()
		}
		
		viewDidLoad()
	}
	
	@IBAction func writeToDevelopers(_ sender: UIButton) {
				UIApplication.shared.openURL(NSURL(string: "http://vk.me/ownradio")! as URL)
	}
	
	@IBAction func rateAppBtn(_ sender: UIButton) {
		UIApplication.shared.openURL(NSURL(string: "itms://itunes.apple.com/ru/app/ownradio/id1179868370")! as URL)
	}
}
