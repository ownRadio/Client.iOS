//
//  SettingsViewController.swift
//  OwnRadio
//
//  Created by Alexandra Polunina on 26.07.17.
//  Copyright © 2017 Netvox Lab. All rights reserved.
//

import UIKit
import MediaPlayer
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
	@IBOutlet weak var countPlayingTracksTable: UILabel!

	//получаем таблицу с количеством треков сгруппированных по количестсву их прослушиваний
	var playedTracks: NSArray = CoreDataManager.instance.getGroupedTracks()
	var controlsAudioDelegat: controlsAudio?

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
		
		
		var str = "" as NSString
		for track in playedTracks {
		let dict = track as! [String: Any]
		let countOfPlay = dict["countPlay"] as? Int
		let countOfTracks = dict["count"] as? Int
		if countOfPlay != nil && countOfTracks != nil {
			if str == "" {
				str = NSString(format: "Count play: %d - Count tracks: %d", countOfPlay! , countOfTracks!)
			} else {
				str = NSString(format: "%@ \nCount play: %d - Count tracks: %d", str, countOfPlay! , countOfTracks!)
			}
			}
		}
		
		countPlayingTracksTable.numberOfLines = playedTracks.count
		countPlayingTracksTable.text = str as String
		
		
		UIApplication.shared.beginReceivingRemoteControlEvents()
		let commandCenter = MPRemoteCommandCenter.shared()
		
		let handler: (String) -> ((MPRemoteCommandEvent) -> (MPRemoteCommandHandlerStatus)) = { (name) in
			return { (event) -> MPRemoteCommandHandlerStatus in
				dump("\(name) \(event.timestamp) \(event.command)")
				return .success
			}
		}
		
		commandCenter.nextTrackCommand.isEnabled = true
		commandCenter.nextTrackCommand.addTarget(handler: handler("skipSong"))
		
		commandCenter.playCommand.isEnabled = true
		commandCenter.playCommand.addTarget(handler: handler("resumeSong"))
		
		commandCenter.pauseCommand.isEnabled = true
		commandCenter.pauseCommand.addTarget(handler: handler("pauseSong"))
		
		NotificationCenter.default.addObserver(self, selector: #selector(AudioPlayerManager.sharedInstance.onAudioSessionEvent(_:)), name: Notification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
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
				CoreDataManager.instance.saveContext()
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
			
//			NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateUIAfterCleanCache"), object: nil)
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
	
	
	override func remoteControlReceived(with event: UIEvent?) {
		guard let controlsAudio = controlsAudioDelegat else {
			print("ControlsAudio delegate wasn't set!")
			return
		}
		controlsAudio.remoteControlReceived(with: event)
	}
//	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
////		if indexPath.section == 4 && indexPath.row == 0 {
////
////			return 100
////		} else {
////			let row = tableView.cellForRow(at: indexPath)// dequeueReusableCell(withIdentifier: "Cell")//(at: indexPath) //.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
////			let h = row?.bounds.size.height
////			print (h ?? 1)
//			return UITableViewAutomaticDimension
////		}
//	}
	// MARK: UITableViewDataSource
	//	 override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
	////		if section == 4 {
	//			return self.playedTracks.count-1
	////		}
	////		if (section == 0) {
	////			return 1;
	////		} else {
	////			var frcSection = section - 1;
	////			id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:frcSection];
	////			return sectionInfo numberOfObjects];
	////		}
	//	}
	
//		 override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//			let cell = tableView.cellForRow(at: indexPath) //countListeningTableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
//			
////			let dict = playedTracks[indexPath.row] as! [String: Any]
////			let countOfPlay = dict["countPlay"] as? Int
////			let countOfTracks = dict["count"] as? Int
////			if countOfPlay != nil && countOfTracks != nil {
////				let str = NSString(format: "Count play: %d - Count tracks: %d", countOfPlay! , countOfTracks! )
////				cell.textLabel?.text = str as String
////			}
//			return cell
//		}
}
