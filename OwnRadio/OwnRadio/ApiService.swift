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
//		self.nextTrackIDString = ""
	}
	
	
	func getTrackIDFromServer (complition: @escaping (String) -> Void)  {
		
		
		let tracksUrl = URL(string: "http://java.ownradio.ru/api/v2/tracks/")
		let trackurl = tracksUrl?.appendingPathComponent((UserDefaults.standard.object(forKey: "UUIDDevice") as! String)).appendingPathComponent("/next")
		
		guard let url = trackurl else {
			print("Error: cannot create URL")
			return
		}
		let urlRequest = NSURLRequest(url: url as URL)
		
		// set up the session
		let config = URLSessionConfiguration.default
		let session = URLSession(configuration: config)
		
		// make the request
		
		let task = session.dataTask(with: urlRequest as URLRequest, completionHandler: { (data, response, error) in
			// do stuff with response, data & error here
			print(data?.description)
			
			guard error == nil else {
		return
			}
			
			let nextTrackIDString = String(data: data!, encoding: String.Encoding.utf8)!
			complition(nextTrackIDString)
		})
		task.resume()
	}
	

//	func saveHistory(trackId: String, isListen:String) {
//		
//		let historyUrl = URL(string: "http://java.ownradio.ru/api/v2/histories/")
//		let trackIDValue = trackId.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
//		let trackHistoryUrl = historyUrl?.appendingPathComponent((UserDefaults.standard.object(forKey: "UUIDDevice") as! String)).appendingPathComponent(trackIDValue)
//		
//		guard let url = trackHistoryUrl else {
//			print("Error: cannot create URL")
//			return
//		}
//		
//		let request = NSMutableURLRequest(url: url as URL)
//		request.httpMethod = "POST"
//		let nowDate = NSDate()
//		let dateFormatter = DateFormatter()
//		dateFormatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
//		let lastListen = dateFormatter.string(from: nowDate as Date)
//		
//		//		let numberListen = NSNumber.init(integerLiteral: isListen)
//		let dict = ["lastListen":lastListen, "isListen":isListen, "method":"random"] as [String : Any]
//		do {
//			
//			
//			let data = try JSONSerialization.data(withJSONObject: dict, options: [])
////			let dataString = String(data: data, encoding: String.Encoding.utf8)!
//			request.httpBody = data
//			
//		} catch {
//			print("JSON serialization failed:  \(error)")
//		}
//		
//		let task = URLSession.shared.dataTask(with: request as URLRequest){ data,response,error in
//			
//			if data != nil {
//				
//			let dataString = String(data: data!, encoding: String.Encoding.utf8)!
//				print(dataString);
//			}
//
//			if error != nil{
//				print(error?.localizedDescription)
//				return
//			}
////			if let responseJSON = try! JSONSerialization.jsonObject(with: data!, options: []) as? [String:AnyObject]{
////				print(responseJSON)
////			}
//		}
//		
//		task.resume()
//
//	}
	
}
