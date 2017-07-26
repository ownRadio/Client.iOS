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
	
	override func viewDidLoad() {
		super.viewDidLoad()
		let userDefaults = UserDefaults.standard
		
		onlyWiFiSwitch.isOn = (userDefaults.object(forKey: "isOnlyWiFi") as? Bool)!
		
		stepper.wraps = true
		stepper.autorepeat = true
		stepper.value = (userDefaults.object(forKey: "maxMemorySize") as? Double)!
		
		stepper.minimumValue = 1.0
		stepper.maximumValue = 64.0
		maxMemoryLbl.text = (userDefaults.object(forKey: "maxMemorySize") as? Int)!.description  + " Gb"
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
			Downloader.sharedInstance.load {
				let tracksUrlString =  FileManager.applicationSupportDir().appending("/Tracks/")
				let limitMemory =  UInt64(DiskStatus.freeDiskSpaceInBytes / 2)
				var maxMemory = UInt64(1073741824)
				if limitMemory < 1073741824 * (UserDefaults.standard.object(forKey: "maxMemorySize") as? UInt64)! {
					maxMemory = limitMemory
				} else {
					maxMemory = 1073741824 * (UserDefaults.standard.object(forKey: "maxMemorySize") as? UInt64)!
				}
				
				if DiskStatus.folderSize(folderPath: tracksUrlString) < maxMemory  {
					return
				} else {
					
				}
			}
		}
		print("fill")
	}
}
