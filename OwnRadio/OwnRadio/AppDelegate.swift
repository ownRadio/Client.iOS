//
//  AppDelegate.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 11/22/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	
	var window: UIWindow?
	
	//с этой функции начинается загрузка приложения
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		// Override point for customization after application launch.
		
		let userDefaults = UserDefaults.standard
		//для получения отчетов об ошибках на фабрик
		Fabric.with([Crashlytics.self, Answers.self])
		
		//если устройству не назначен deviceId - генерируем новый
		if userDefaults.object(forKey: "UUIDDevice") == nil {
			let UUID = NSUUID().uuidString.lowercased() //"17096171-1C39-4290-AE50-907D7E62F36A" //
			userDefaults.set(UUID, forKey: "UUIDDevice")
			userDefaults.synchronize()
		}
		
		// создаем папку Tracks если ее нет
		let applicationSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let tracksPath = applicationSupportPath.appendingPathComponent("Tracks")
		do {
			try FileManager.default.createDirectory(at: tracksPath, withIntermediateDirectories: true, attributes: nil)
		} catch let error as NSError {
			NSLog("Unable to create directory \(error.debugDescription)")
		}
		//проверяем была ли совершена миграция
		if userDefaults.object(forKey: "MigrationWasDoneV2") == nil
		{
			DispatchQueue.global().async {
				do{
					// получаем содержимое папки Documents
					if let tracksContents = try? FileManager.default.contentsOfDirectory(atPath: FileManager.docDir()){

						self.removeFilesFromDirectory(tracksContents: tracksContents)

					}
					if let tracksContents = try? FileManager.default.contentsOfDirectory(atPath: FileManager.docDir().appending("/Tracks")) {
						self.removeFilesFromDirectory(tracksContents: tracksContents)
					}
					//удаляем треки из базы
					CoreDataManager.instance.deleteAllTracks()
					// устанавливаем флаг о прохождении миграции
					userDefaults.set(true, forKey: "MigrationWasDoneV2")
					userDefaults.synchronize()
				}
			}
		}
		return true
	}
	
	func removeFilesFromDirectory (tracksContents:[String]) {
		//если в папке больше 4 файлов (3 файла Sqlite и папка Tracks) то пытаемся удалить треки
		if tracksContents.count > 1 {
			for track in tracksContents {
				// проверка для удаления только треков
//				if track.contains("mp3") {
					let atPath = FileManager.docDir().appending("/").appending(track)
					do{
						print(atPath)
						try FileManager.default.removeItem(atPath: atPath)
						
					} catch  {
						print("error with move file reason - \(error)")
					}
//				}
			}
			
			
		}
	}
	
	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
	}
	
	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}
	
	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
	}
	
	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}
	
	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}

}

