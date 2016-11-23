//
//  AudioPlayer.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 11/23/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//

import Foundation
import AVFoundation

class AudioPlayerManager {
	var player: AVPlayer!
	static let sharedInstance = AudioPlayerManager()
	
	func playAudioWith(trackID:String) {
		
		var arr =  trackID.components(separatedBy: "\"")
		let trackIDValue = arr[1]
		let urlString = "http://java.ownradio.ru/api/v2/tracks/" + trackIDValue
		let URL = NSURL(string: urlString) as! URL
//		let playerItem = AVPlayerItem( url:URL)
//		player = AVPlayer(playerItem:playerItem)
		
		let asset = AVURLAsset(url: URL)
		let playerItem = AVPlayerItem(asset: asset)
		
		player = AVPlayer(playerItem: playerItem)
		
		player.play()
		
	}
	

}
