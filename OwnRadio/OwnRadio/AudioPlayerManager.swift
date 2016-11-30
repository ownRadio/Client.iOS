//
//  AudioPlayer.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 11/23/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.

//

import Foundation
import AVFoundation
import UIKit
import MediaPlayer

class AudioPlayerManager: NSObject {
	var player: AVPlayer!
	var playerItem: AVPlayerItem!
	var isPlaying: Bool!
	var playedSongID: String!
	var playingSongID: String!
	
	var titleSong: String!
	var playbackProgres: CMTime!
	var currentPlaybackTime: CMTime!
	
	static let sharedInstance = AudioPlayerManager()
	override init() {
		super.init()
//		NotificationCenter.default.addObserver(self, selector: #selector(songDidPlay), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
		
		NotificationCenter.default.addObserver(self, selector: #selector(crashNetwork(_:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
				setup()
	}
	
	deinit {
//		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
	}
	
	// playing audio by track id
	func playAudioWith(trackID:String) {
		
		let baseURL = URL(string: "http://java.ownradio.ru/api/v2/tracks/")
		let trackURL = baseURL?.appendingPathComponent(trackID)
		
		guard let url = trackURL else {
			return
		}
		
		let asset = AVURLAsset(url: url)
		playerItem = AVPlayerItem(asset: asset)
		player = AVPlayer(playerItem: playerItem)
		player.play()
		
		isPlaying = true
		

	}
	
	func setup() {
		let audioSession = AVAudioSession.sharedInstance()
		
		try! audioSession.setCategory(AVAudioSessionCategoryPlayback)
		try! audioSession.setActive(true)
		
		UIApplication.shared.beginReceivingRemoteControlEvents()
		
		NotificationCenter.default.addObserver(self, selector: #selector(onAudioSessionEvent(_:)), name: Notification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
	}
	
	func onAudioSessionEvent(_ notification: Notification) {
		//Check the type of notification, especially if you are sending multiple AVAudioSession events here
		if (notification.name == NSNotification.Name.AVAudioSessionInterruption) {
			if (self.isPlaying != nil) {
				return
			}
			
			
		}
	}

	///  confirure album cover and other params for playing song
	func configurePlayingSong() {
		
		let albumArt = MPMediaItemArtwork(image: UIImage(named:"iconBig")!)
		var songInfo = [String:Any]()
		
//		songInfo[MPMediaItemPropertyTitle] = titleSong
		songInfo[MPMediaItemPropertyTitle] = "ownRadio"
		songInfo[MPMediaItemPropertyAlbumTitle] = "ownRadio"
		songInfo[MPMediaItemPropertyArtist] = "ownRadio"
		songInfo[MPMediaItemPropertyArtwork] = albumArt
//		songInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playbackProgres
//		songInfo[MPMediaItemPropertyPlaybackDuration] = currentPlaybackTime

		MPNowPlayingInfoCenter.default().nowPlayingInfo = songInfo
	}
	
	func crashNetwork(_ notification: Notification) {
//		self.player = nil
		self.playerItem = nil
		
	}
	func resumeSong() {

		if self.playerItem != nil {
		self.player?.play()
		} else {
			self.nextTrack(complition: nil)
		}
		isPlaying = true
	}
	
	func pauseSong() {
		
		self.player?.pause()
		isPlaying = false
	}
	
//	func songDidPlay() {
////		ApiService.shared.saveHistory(trackId: playingSongID, isListen: "1")
//		nextTrack(complition: nil)
//	}
	func skipSong() {
		if (self.playingSongID != nil) {
//			ApiService.shared.saveHistory(trackId: playingSongID, isListen: "-1")
		}
		nextTrack(complition: nil)
	}
	
	func nextTrack(complition: (() -> Void)?) {
		ApiService.shared.getTrackIDFromServer { (resultString) in
			let trackIDValue = resultString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
			self.playAudioWith(trackID: trackIDValue)
			self.playedSongID = self.playingSongID
			self.playingSongID = trackIDValue
			self.titleSong = resultString
			self.configurePlayingSong()
			if complition != nil {
			complition!()
			}
		}
	}
}
