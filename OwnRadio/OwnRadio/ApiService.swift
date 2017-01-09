//
//  Api Service.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 11/22/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//
// Managing with api requests

import Foundation


class ApiService {
	
	let tracksUrl = URL(string: "http://api.ownradio.ru/v3/tracks/")
	static let shared = ApiService()
	init() {

	}

    //возвращает информацию о следующем треке
	func getTrackIDFromServer (complition:  @escaping ([String:AnyObject]) -> Void)  {
		
		//формируем URL
		let trackurl = self.tracksUrl?.appendingPathComponent((UserDefaults.standard.object(forKey: "UUIDDevice") as! String)).appendingPathComponent("/next")
		
		guard let url = trackurl else {
			print("Error: cannot create URL")
			return
		}
		let urlRequest = NSURLRequest(url: url as URL)
		
		// set up the session
		let config = URLSessionConfiguration.default
		let session = URLSession(configuration: config)
		
		//выполняем запрос к серверу
		let task = session.dataTask(with: urlRequest as URLRequest, completionHandler: { (data, response, error) in
			// do stuff with response, data & error here
			
			guard let data = data else {
				return
			}

			do {
                //преобразовываем полученные данные в JSON-объект
				let anyJson = try JSONSerialization.jsonObject(with: data, options: [])
				
				if let json = anyJson as? [String:AnyObject] {
						complition(json)
				}
			} catch (let error) {
				print("Achtung! Eror! \(error)")
			}
		
		})
		task.resume()
	}
	
    //функция сохранения истории прослушивания треков
	func saveHistory(trackId: String, isListen:Int) {
		
		let historyUrl = URL(string: "http://api.ownradio.ru/v3/histories/")
        //формируем URL
		let trackHistoryUrl = historyUrl?.appendingPathComponent((UserDefaults.standard.object(forKey: "UUIDDevice") as! String)).appendingPathComponent(trackId)
		
		guard let url = trackHistoryUrl else {
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
		
        //формируем тело запроса
		let dict = ["lastListen":lastListen, "isListen":isListen, "methodid":1] as [String : Any]
		do {
			
			let data = try JSONSerialization.data(withJSONObject: dict, options: [])
//			let dataString = String(data: data, encoding: String.Encoding.utf8)!
			request.httpBody = data
			
		} catch {
			print("JSON serialization failed:  \(error)")
		}
		
        //выполняем запрос к серверу
		let task = URLSession.shared.dataTask(with: request as URLRequest){ data,response,error in
			
			if data != nil {
			
			CoreDataManager.instance.deleteHistoryFor(trackID: trackId)
				
//			let dataString = String(data: data!, encoding: String.Encoding.utf8)!
			}

			if error != nil{
				print(error?.localizedDescription)
				return
			}
		}
		task.resume()
	}
}
