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
	var playingSong = SongObject()
	var isPlaying: Bool!
	
	var playingSongID: String?
	var titleSong: String!
	
	var playbackProgres: CMTime!
	var currentPlaybackTime: CMTime!
	var timer = Timer()
	
	
	static let sharedInstance = AudioPlayerManager()
	override init() {
		super.init()
		
		
		//		NotificationCenter.default.addObserver(self, selector: #selector(songDidPlay), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
		
		NotificationCenter.default.addObserver(self, selector: #selector(crashNetwork(_:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem)
		setup()
	}
	
	deinit {
		//		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
	}
	
		func setup() {
		let audioSession = AVAudioSession.sharedInstance()
		
		try! audioSession.setCategory(AVAudioSessionCategoryPlayback)
		try! audioSession.setActive(true)
			
		
		
		UIApplication.shared.beginReceivingRemoteControlEvents()
		
		NotificationCenter.default.addObserver(self, selector: #selector(onAudioSessionEvent(_:)), name: Notification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
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
	
	
	func onAudioSessionEvent(_ notification: Notification) {
		//Check the type of notification, especially if you are sending multiple AVAudioSession events here
		if (notification.name == NSNotification.Name.AVAudioSessionInterruption) {
			if (self.isPlaying != nil) {
				return
			}
		}
	}
	
	func crashNetwork(_ notification: Notification) {
		self.playerItem = nil
	}
	
	///  confirure album cover and other params for playing song
	func configurePlayingSong(song:SongObject) {
		
		let albumArt = MPMediaItemArtwork(image: UIImage(named:"iconBig")!)
		var songInfo = [String:Any]()
		
		songInfo[MPMediaItemPropertyTitle] = song.name
		songInfo[MPMediaItemPropertyAlbumTitle] = "ownRadio"
		songInfo[MPMediaItemPropertyArtist] = song.artistName
		songInfo[MPMediaItemPropertyArtwork] = albumArt
//		songInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
		songInfo[MPMediaItemPropertyPlaybackDuration] = song.trackLength
		
		MPNowPlayingInfoCenter.default().nowPlayingInfo = songInfo
	}
	
	
	
	func resumeSong(complition: (() -> Void)?) {
		
		if self.playerItem != nil {
			self.player?.play()
		} else {
			self.nextTrack(complition: complition)
		}
		isPlaying = true
	}
	
	func pauseSong() {
		
		self.player?.pause()
		isPlaying = false
	}
	
	
	func skipSong(complition: (() -> Void)?) {
		if (self.playingSongID != nil) {
			ApiService.shared.saveHistory(trackId: self.playingSong.trackID, isListen: "-1")
		}
		nextTrack(complition: complition)
	}
	
	func nextTrack(complition: (() -> Void)?) {
		ApiService.shared.getTrackIDFromServer {  (dictionary) in
			
			self.playingSong = SongObject()
			
			self.playingSong.initWithDict(dict: dictionary)
			
			
			self.playAudioWith(trackID: self.playingSong.trackID)
			
			self.playingSongID = self.playingSong.trackID
			self.titleSong = self.playingSong.name
			self.configurePlayingSong(song: self.playingSong)
			if complition != nil {
				complition!()
			}
		}
	}
}
