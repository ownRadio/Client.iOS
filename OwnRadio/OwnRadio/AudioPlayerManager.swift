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

class AudioPlayerManager: NSObject, AVAssetResourceLoaderDelegate, NSURLConnectionDataDelegate {
	
	var player: AVPlayer = AVPlayer()
	var playerItem: AVPlayerItem!
	var asset: AVURLAsset?
	static let sharedInstance = AudioPlayerManager()
	
	var isPlaying: Bool?
	var canPlayFromCache = false
	
	var playingSong = SongObject()
	
	var playingSongID: String?
	var titleSong: String!
	var assetUrlStr: String?
	let baseURL = URL(string: "http://api.ownradio.ru/v3/tracks/")
	
	var playbackProgres: CMTime!
	var currentPlaybackTime: CMTime!
	var timer = Timer()
	
	// MARK: Overrides
	override init() {
		super.init()
		
		
		
		NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(crashNetwork(_:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem)
		setup()
	}
	
	deinit {
		
		playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
		
		
		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: self.playerItem)
		NotificationCenter.default.removeObserver(self, name: Notification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
	}
	
	func setup() {
//		let audioSession = AVAudioSession.sharedInstance()
//		
//		try! audioSession.setCategory(AVAudioSessionCategoryPlayback)
//		try! audioSession.setActive(true)
		
		
		print("unducking")
		let sess = AVAudioSession.sharedInstance()
		try? sess.setActive(false)
		let opts = sess.categoryOptions.symmetricDifference(.duckOthers)
		try? sess.setCategory(sess.category, with: opts)
//		try? sess.setCategory(sess.category, mode: sess.mode, options:opts)
		try? sess.setActive(true)
		
		
		
		UIApplication.shared.beginReceivingRemoteControlEvents()
		
		NotificationCenter.default.addObserver(self, selector: #selector(onAudioSessionEvent(_:)), name: Notification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
	}
	
	// MARK: KVO
	
	override func observeValue(forKeyPath keyPath: String?,
	                           of object: Any?,
	                           change: [NSKeyValueChangeKey : Any]?,
	                           context: UnsafeMutableRawPointer?) {
		
		if keyPath == #keyPath(AVPlayerItem.status) {
			let status: AVPlayerItemStatus
			
			// Get the status change from the change dictionary
			if let statusNumber = change?[.newKey] as? NSNumber {
				status = AVPlayerItemStatus(rawValue: statusNumber.intValue)!
			} else {
				status = .unknown
			}
			
			// Switch over the status
			switch status {
			case .readyToPlay:
				player.play()
				isPlaying = true
				DispatchQueue.global(qos: .background).async {
					Downloader.load {
						
					}
				}
			case .failed:
				break
			case .unknown:
				break
				// Player item is not yet ready.
			}
		}
	}
	
	// MARK: Notification selectors
	
	func playerItemDidReachEnd(_ notification: Notification) {
		
		if notification.object as? AVPlayerItem  == player.currentItem {
			//			self.playerItem = nil
			self.playingSong.isListen = 1
			self.addDateToHistoryTable(playingSong: self.playingSong)
		}
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
		//		self.playerItem = nil
		self.player.pause()
		guard currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable else {
			return
		}
		self.nextTrack(complition: nil)
		
	}
	
	///  confirure album cover and other params for playing song
	func configurePlayingSong(song:SongObject) {
		
		let albumArt = MPMediaItemArtwork(image: UIImage(named:"iconBig")!)
		var songInfo = [String:Any]()
		
		songInfo[MPMediaItemPropertyTitle] = song.name
		songInfo[MPMediaItemPropertyAlbumTitle] = "ownRadio"
		songInfo[MPMediaItemPropertyArtist] = song.artistName
		songInfo[MPMediaItemPropertyArtwork] = albumArt
		songInfo[MPMediaItemPropertyPlaybackDuration] = song.trackLength
		
		MPNowPlayingInfoCenter.default().nowPlayingInfo = songInfo
	}
	
	// MARK: Cotrol functions
	func resumeSong(complition: @escaping (() -> Void)) {
		
		if self.playerItem != nil {
			self.player.play()
			isPlaying = true
			complition()
		} else {
			self.nextTrack(complition: complition)
		}
	}
	
	func pauseSong(complition: (() -> Void)) {
		
		self.player.pause()
		isPlaying = false
		complition()
		
	}
	
	func skipSong(complition: (() -> Void)?) {
		self.playingSong.isListen = -1
		//		self.playerItem = nil
		if (self.playingSongID != nil) {
			self.addDateToHistoryTable(playingSong: self.playingSong)
			if  self.playingSong.path != nil {
				let path = FileManager.documentsDir().appending("/").appending(self.playingSong.path!)
				if FileManager.default.fileExists(atPath: path) {
					
					do{
						try FileManager.default.removeItem(atPath: path)
						
					}
					catch {
						print("Error with remove file ")
					}
					CoreDataManager.instance.deleteTrackFor(trackID: self.playingSong.trackID)
				}
			}
			
		}
		nextTrack(complition: complition)
	}
	
	func playAudioWith(trackURL:URL) {
		
		//		self.assetUrlStr = String(describing: trackURL)
		//		self.asset = AVURLAsset(url: trackURL)
		if playerItem != nil {
			playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
		}
		
		createPlayerItemWith(url: trackURL)
		playerItem.addObserver(self,
		                       forKeyPath: #keyPath(AVPlayerItem.status),
		                       options: [.old, .new],
		                       context: nil)
		
		player = AVPlayer(playerItem: playerItem)
		
	}
	
	func createPlayerItemWith(url:URL) {
		if self.canPlayFromCache {
			playerItem = AVPlayerItem.init(url: URL.init(fileURLWithPath: url.relativePath))
		} else {
			playerItem = AVPlayerItem(url: url)
		}
	}
	
	func setWayForPlay(complition: (() -> Void)?) {
		if self.checkCountFileInCache() {
			self.playFromCache(complition: complition)
		} else {
			self.playOnline(complition: complition)
		}
	}
	
	func checkCountFileInCache() -> Bool {
		self.canPlayFromCache = false
		if CoreDataManager.instance.getCountOfTracks() > 10 {
			self.canPlayFromCache = true
		}
		return self.canPlayFromCache
	}
	
	func playOnline(complition: (() -> Void)?) {
		guard  currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable  else {
			return
		}
		
		if CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "HistoryEntity") > 0 {
			CoreDataManager.instance.sentHistory()
		}
		ApiService.shared.getTrackIDFromServer {  (dictionary) in
			
			self.playingSong = SongObject()
			
			self.playingSong.initWithDict(dict: dictionary)
			
			let trackURL = self.baseURL?.appendingPathComponent(self.playingSong.trackID)
			guard let url = trackURL else {
				return
			}
			self.playAudioWith(trackURL: url)
			
			self.playingSongID = self.playingSong.trackID
			self.titleSong = self.playingSong.name
			self.configurePlayingSong(song: self.playingSong)
			if complition != nil {
				complition!()
			}
		}
		
	}
	
	func playFromCache(complition: (() -> Void)?) {
		
		if CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "HistoryEntity") > 0 && currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable{
			CoreDataManager.instance.sentHistory()
		}
		
		self.playingSong = CoreDataManager.instance.getRandomTrack()
		let docUrl = NSURL(string:FileManager.documentsDir())
		let resUrl = docUrl?.absoluteURL?.appendingPathComponent(playingSong.path!)
		guard let url = resUrl else {
			return
		}
		self.playAudioWith(trackURL: url as URL)
		self.playingSongID = self.playingSong.trackID
		self.configurePlayingSong(song: self.playingSong)
		if complition != nil {
			complition!()
		}
	}
	
	func nextTrack(complition: (() -> Void)?) {
		self.setWayForPlay(complition: complition)
	}
	
	func addDateToHistoryTable(playingSong:SongObject) {
		
		let creatinDate = Date()
		let dateFormetter = DateFormatter()
		dateFormetter.dateFormat = "yyyy-MM-dd'T'H:m:s"
		let creationDateString = dateFormetter.string(from: creatinDate)
		let historyEntity = HistoryEntity()
		
		historyEntity.recId = playingSong.trackID
		historyEntity.trackId = playingSong.trackID
		historyEntity.isListen = playingSong.isListen!
		historyEntity.recCreated = creationDateString
		
		CoreDataManager.instance.saveContext()
	}
}
