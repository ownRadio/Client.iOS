//
//  Api Service.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 11/22/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//
// Managing with api requests

import Foundation
import UIKit

class ApiService {
	
	let tracksUrl = URL(string: "http://api.ownradio.ru/v3/tracks/")
	var countRequest:Int! = 0
	static let shared = ApiService()
	init() {

	}

	//возвращает информацию о следующем треке
	func getTrackIDFromServer (complition:  @escaping ([String:AnyObject]) -> Void)  {
		
		//формируем URL для получения информации о следующем треке (trackId, name, artist, methodId, length)
		let trackurl = self.tracksUrl?.appendingPathComponent((UIDevice.current.identifierForVendor?.uuidString.lowercased())!).appendingPathComponent("/next")
		
		guard let url = trackurl else {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Error: cannot create URL"])
			print("Error: cannot create URL")
			return
		}
		let urlRequest = NSURLRequest(url: url as URL)
		
		// set up the session
		let config = URLSessionConfiguration.default
		let session = URLSession(configuration: config)
		print(urlRequest.description)
		
		let task = session.dataTask(with: urlRequest as URLRequest, completionHandler: { (data, response, error) in
			// do stuff with response, data & error here
			
			if error != nil {
				if self.countRequest < 10 {
					Downloader.sharedInstance.load(complition: { 
						
					})
				}
			}
			guard let data = data else {
				return
			}
			if let httpResponse = response as? HTTPURLResponse {
				if httpResponse.statusCode == 200 {
					
					do {
						let anyJson = try JSONSerialization.jsonObject(with: data, options: [])
						
						if let json = anyJson as? [String:AnyObject] {
							complition(json)
						}
						NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Получена информация о следующем треке"])
						print("Получена информация о следующем треке")
					} catch (let error) {
						print("Achtung! Eror! \(error)")
					}
				}
			}
		})
		
		task.resume()
		
	}
	
	//функция сохранения истории прослушивания треков
    func saveHistory(historyId: String, trackId: String, isListen:Int) {
		
		let historyUrl = URL(string: "http://api.ownradio.ru/v5/histories/")
		//формируем URL для отправки истории прослушивания на сервер
		let trackHistoryUrl = historyUrl?.appendingPathComponent((UIDevice.current.identifierForVendor?.uuidString.lowercased())!).appendingPathComponent(trackId)
		
		guard let url = trackHistoryUrl else {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"Error: cannot create URL"])
			print("Error: cannot create URL")
			return
		}
		
		let request = NSMutableURLRequest(url: url as URL)
		request.httpMethod = "POST"
		let nowDate = NSDate()
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd'T'H:m:s"
		dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
		let lastListen = dateFormatter.string(from: nowDate as Date)

		request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
		
		//добавляем параметры в тело запроса: lastListen - дата и время последнего прослушивания трека,
		//isListen - флаг прослушан или пропущен трек, methodid - метод выдачи трека пользователю
		let dict = ["recid":historyId, "lastListen":lastListen, "isListen":isListen] as [String : Any]
		do {
			let data = try JSONSerialization.data(withJSONObject: dict, options: [])
//			let dataString = String(data: data, encoding: String.Encoding.utf8)!
			request.httpBody = data
			
			
		} catch {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"JSON serialization failed: \(error)"])
			print("JSON serialization failed:  \(error)")
		}
		
		//отправляем историю на сервер
		let task = URLSession.shared.dataTask(with: request as URLRequest){ data,response,error in
			
			if error != nil{
				print(error?.localizedDescription)
				return
			}
			
			if let httpResponse = response as? HTTPURLResponse {
				print("status code \(httpResponse.statusCode)")
                if (httpResponse.allHeaderFields["Location"] as? String) != nil || httpResponse.statusCode == 201 {
                        if data != nil {
                            //если история передана успешна - удаляем из таблицы история запись об этом треке
                            CoreDataManager.instance.deleteHistoryFor(trackID: trackId)
                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"История передана на сервер, код: \(httpResponse.statusCode)"])
                            print("История передана на сервер")
						
                            //			let dataString = String(data: data!, encoding: String.Encoding.utf8)!
                        }
                } else {
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":"История не передана, код: \(httpResponse.statusCode)"])
                }
			}
			
		}
		task.resume()
		
	}
}
