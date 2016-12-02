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

class AudioPlayerManager: NSObject, AVAssetResourceLoaderDelegate {
	var player: AVPlayer!
	var playerItem: AVPlayerItem!
	var playingSong = SongObject()
	var isPlaying: Bool?
	
	var playingSongID: String?
	var titleSong: String!
	
	var playbackProgres: CMTime!
	var currentPlaybackTime: CMTime!
	var timer = Timer()
	var pendingRequests: NSMutableArray?
	
	static let sharedInstance = AudioPlayerManager()
	override init() {
		super.init()
		
		NotificationCenter.default.addObserver(self, selector: #selector(songDidPlay), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
		
		NotificationCenter.default.addObserver(self, selector: #selector(crashNetwork(_:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem)
		setup()
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
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
		
		let baseURL = URL(string: "http://api.ownradio.ru/v3/tracks/")
		let trackURL = baseURL?.appendingPathComponent(trackID)
		
		guard let url = trackURL else {
			return
		}
		let asset = AVURLAsset(url: url)
		asset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
		self.pendingRequests = NSMutableArray()
		
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
	
	// MARK:
	func crashNetwork(_ notification: Notification) {
		self.playerItem = nil
		guard currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable else {
			return
		}
		self.nextTrack(complition: nil)
		
	}
	
	func songDidPlay() {
		self.playerItem = nil
		self.playingSong.isListen = 1
		self.addDateToHistoryTable(playingSong: self.playingSong)
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
	
	
	
	func resumeSong(complition: @escaping (() -> Void)) {
		
		if self.playerItem != nil {
			self.player?.play()
			isPlaying = true
			complition()
		} else {
			self.nextTrack(complition: complition)
		}
		
	}
	
	func pauseSong(complition: (() -> Void)) {
		
		self.player?.pause()
		isPlaying = false
		complition()
		
	}
	
	
	func skipSong(complition: (() -> Void)?) {
		self.playingSong.isListen = -1
		self.playerItem = nil 
		if (self.playingSongID != nil) {
			self.addDateToHistoryTable(playingSong: self.playingSong)
		}
		nextTrack(complition: complition)
	}
	
	func nextTrack(complition: (() -> Void)?) {
		
		guard  currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable  else {
			complition!()
			return
		}

		if CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "HIstoryEntity") > 0 {
			
		CoreDataManager.instance.sentHistory()

		}
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

	//MARK: AVAssetResourceLoaderDelegate
	
//	func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
//		
//	}
	
	
	
	func addDateToHistoryTable(playingSong:SongObject) {
		
		let creatinDate = Date()
		let dateFormetter = DateFormatter()
		dateFormetter.dateFormat = "yyyy-MM-dd'T'H:m:s"
		let creationDateString = dateFormetter.string(from: creatinDate)
		let historyEntity = HIstoryEntity()
		
		historyEntity.recId = playingSong.trackID
		historyEntity.trackId = playingSong.trackID
		historyEntity.isListen = playingSong.isListen!
		historyEntity.recCreated = creationDateString
		
		CoreDataManager.instance.saveContext()
	}
	
	
}
