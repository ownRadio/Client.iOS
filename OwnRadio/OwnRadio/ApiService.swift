//
//  Api Service.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 11/22/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//
// Managed

import Foundation


class ApiService {
	
//	var nextTrackIDString: String
	static let shared = ApiService()
	init() {

	}
	
	
	func getTrackIDFromServer (complition:  @escaping ([String:AnyObject]) -> Void)  {
		
		
		let tracksUrl = URL(string: "http://api.ownradio.ru/v3/tracks/")
		let trackurl = tracksUrl?.appendingPathComponent((UserDefaults.standard.object(forKey: "UUIDDevice") as! String)).appendingPathComponent("/next")
		
		guard let url = trackurl else {
			print("Error: cannot create URL")
			return
		}
		let urlRequest = NSURLRequest(url: url as URL)
		
		// set up the session
		let config = URLSessionConfiguration.default
		let session = URLSession(configuration: config)
		
		
		let task = session.dataTask(with: urlRequest as URLRequest, completionHandler: { (data, response, error) in
			// do stuff with response, data & error here
			
			guard let data = data else {
				return
			}

			do {
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
	

	func saveHistory(trackId: String, isListen:Int) {
		
		let historyUrl = URL(string: "http://api.ownradio.ru/v3/histories/")
		let trackIDValue = trackId.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
		let trackHistoryUrl = historyUrl?.appendingPathComponent((UserDefaults.standard.object(forKey: "UUIDDevice") as! String)).appendingPathComponent(trackIDValue)
		
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
		
		let dict = ["lastListen":lastListen, "isListen":isListen, "methodid":1] as [String : Any]
		do {
			
			
			let data = try JSONSerialization.data(withJSONObject: dict, options: [])
			let dataString = String(data: data, encoding: String.Encoding.utf8)!
			request.httpBody = data
			print(dataString)
			
		} catch {
			print("JSON serialization failed:  \(error)")
		}
		
		let task = URLSession.shared.dataTask(with: request as URLRequest){ data,response,error in
			
			if data != nil {
				
			let dataString = String(data: data!, encoding: String.Encoding.utf8)!
				print(dataString);
			}

			if error != nil{
				print(error?.localizedDescription)
				return
			}
		}
		
		task.resume()

	}
	
}
