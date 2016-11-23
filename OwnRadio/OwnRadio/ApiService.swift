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
		
		let urlString = "http://java.ownradio.ru/api/v2/tracks/" + (UserDefaults.standard.object(forKey: "UUIDDevice") as! String) + "/next"
		guard let url = NSURL(string: urlString) else {
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
			
			self.getMediaTrackFromServer()
			
		})
		task.resume()
	}
	
	func getMediaTrackFromServer() {
		
////		let urlString = "http://java.ownradio.ru/api/v2/tracks/" + self.nextTrackIDString
//		
//		guard let url = NSURL(string: urlString) else {
//			print("Error: cannot create URL")
//			return
//		}
//		let urlRequest = NSURLRequest(url: url as URL)
//		
//		// set up the session
//		let config = URLSessionConfiguration.default
//		let session = URLSession(configuration: config)
//		
//		// make the request
//		
//		let task = session.dataTask(with: urlRequest as URLRequest, completionHandler: { (data, response, error) in
//			// do stuff with response, data & error here
//			print(data?.description)
//			
//			guard error == nil else {
//				return
//			}
//			
//			
//			
//		})
//		task.resume()

		
	}
	
	
}
