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
	@IBOutlet weak var versionLbl: UILabel!
	@IBOutlet weak var deviceIdLbl: UILabel!

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
		
		if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
			if (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) != nil {
				versionLbl.text =  "Version: v" + version
			}
		}
		deviceIdLbl.text = "DeviceID: " + (UIDevice.current.identifierForVendor?.uuidString.lowercased())!
		
	}
	
	@IBAction func onlyWiFiSwitchValueChanged(_ sender: UISwitch) {
		UserDefaults.standard.set(onlyWiFiSwitch.isOn, forKey: "isOnlyWiFi")
		UserDefaults.standard.synchronize()
	}
	
	//Сохраняем настроки "занимать не более" и выводим актуальное значение при его изменении
	@IBAction func stepperValueChanged(_ sender: UIStepper) {
		maxMemoryLbl.text = Int(stepper.value).description + " Gb"
		UserDefaults.standard.set(stepper.value, forKey: "maxMemorySize")
		UserDefaults.standard.synchronize()
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
		let dellAllTracksAlert = UIAlertController(title: "Удаление всех треков", message: "Вы уверены что хотите удалить все треки из кэша? Приложение не сможет проигрывать треки в офлайне пока не будет наполнен кэш.", preferredStyle: UIAlertControllerStyle.alert)
		
		dellAllTracksAlert.addAction(UIAlertAction(title: "ОК", style: .default, handler: { (action: UIAlertAction!) in
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
				
				self.viewDidLoad()
			}
			
			
		}))
		
		dellAllTracksAlert.addAction(UIAlertAction(title: "ОТМЕНА", style: .cancel, handler: { (action: UIAlertAction!) in
			
		}))
		
		present(dellAllTracksAlert, animated: true, completion: nil)
		
		
	}
	
	@IBAction func delListenTracksBtn(_ sender: UIButton) {
		let dellListenTracksAlert = UIAlertController(title: "Удаление прослушанных треков", message: "Вы хотите удалить прослушанные треки из кэша?", preferredStyle: UIAlertControllerStyle.alert)
		
		dellListenTracksAlert.addAction(UIAlertAction(title: "ОК", style: .default, handler: { (action: UIAlertAction!) in
			
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
			
			self.viewDidLoad()
		}))
		
		dellListenTracksAlert.addAction(UIAlertAction(title: "ОТМЕНА", style: .cancel, handler: { (action: UIAlertAction!) in
		}))
		
		present(dellListenTracksAlert, animated: true, completion: nil)
	}
	
	@IBAction func writeToDevelopers(_ sender: UIButton) {
		UIApplication.shared.openURL(NSURL(string: "http://www.vk.me/write-87060547")! as URL)
	}
	
	@IBAction func rateAppBtn(_ sender: UIButton) {
		UIApplication.shared.openURL(NSURL(string: "itms://itunes.apple.com/ru/app/ownradio/id1179868370")! as URL)
	}
}
