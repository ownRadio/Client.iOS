//
//  AudioPlayer.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 11/23/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.

//	Audio manager, set audio session and managing with player

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
	
	var playbackProgres: Double!
	var currentPlaybackTime: CMTime!
	var timer = Timer()
	
	var wasInterreption = false
	
	// MARK: Overrides
	override init() {
		super.init()

        //подписываемся на уведомления
		NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player.currentItem)
		
		NotificationCenter.default.addObserver(self, selector: #selector(crashNetwork(_:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: self.player.currentItem)
		setup()
	}
	
	deinit {
		
		playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
		
		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player.currentItem)
		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: self.player.currentItem)
		NotificationCenter.default.removeObserver(self, name: Notification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
	}
	
	func setup() {
		let audioSession = AVAudioSession.sharedInstance()
		
		try! audioSession.setCategory(AVAudioSessionCategoryPlayback)
		try! audioSession.setMode(AVAudioSessionModeDefault)
		try! audioSession.setActive(true)
		
		UIApplication.shared.beginReceivingRemoteControlEvents()
		
		NotificationCenter.default.addObserver(self, selector: #selector(onAudioSessionEvent(_:)), name: Notification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
	}

	// MARK: KVO
    // подключение/отключение гарнитуры
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
				if wasInterreption {
					wasInterreption = false
				} else {
					player.play()
					isPlaying = true
					DispatchQueue.global(qos: .background).async {
						Downloader.load {
							
						}
					}
				}
				
			case .failed:
				break
			case .unknown:
				break
				
			}
		}
	}
	
	// MARK: Notification selectors
    // трек дослушан до конца
	func playerItemDidReachEnd(_ notification: Notification) {
		
		if notification.object as? AVPlayerItem  == player.currentItem {
			self.playingSong.isListen = 1
			self.addDateToHistoryTable(playingSong: self.playingSong)
			if self.playingSong.trackID != nil  {
				CoreDataManager.instance.setDateForTrackBy(trackId: self.playingSong.trackID)
				CoreDataManager.instance.saveContext()
			}
		}
	}
	
    //обработка прерывания аудиосессии
	func onAudioSessionEvent(_ notification: Notification) {
		
		guard notification.name == Notification.Name.AVAudioSessionInterruption else {
			return
		}
		
		guard let userInfo = notification.userInfo as? [String: AnyObject] else { return }
		guard let rawInterruptionType = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber else { return }
        //получаем информацию о прерывании
		guard let interruptionType = AVAudioSessionInterruptionType.init(rawValue: rawInterruptionType.uintValue) else {
			return
		}
		
		switch interruptionType {
	
		case .ended: //interruption ended
			print("ENDED")
			if let rawInterruptionOption = userInfo[AVAudioSessionInterruptionOptionKey] as? NSNumber {
				let interruptionOption = AVAudioSessionInterruptionOptions(rawValue: rawInterruptionOption.uintValue)
				if interruptionOption == AVAudioSessionInterruptionOptions.shouldResume {
					self.pauseSong {
						
					}
				}
			}

		case .began: //interruption started
			
			if self.isPlaying == true {
				print("Began Playing - TRUE")
			} else {
				print("Began Playing - FALSE")
				wasInterreption = true
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
		print(song.trackLength)
		songInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber.init(value: song.trackLength)
		
		MPNowPlayingInfoCenter.default().nowPlayingInfo = songInfo
	}
	
	// MARK: Cotrol functions
    //возобновление воспроизведения
	func resumeSong(complition: @escaping (() -> Void)) {
		
		if self.playerItem != nil {
			self.player.play()
			isPlaying = true
			complition()
		} else {
			self.nextTrack(complition: complition)
		}
	}
	
    //пауза
	func pauseSong(complition: (() -> Void)) {
		
		self.player.pause()
		isPlaying = false
		complition()
		
	}
	
    //пропуск трека
	func skipSong(complition: (() -> Void)?) {
		self.playingSong.isListen = -1
		//		self.playerItem = nil
		if (self.playingSongID != nil) {
			self.addDateToHistoryTable(playingSong: self.playingSong)
			if  self.playingSong.path != nil {
				let path = FileManager.documentsDir().appending("/").appending(self.playingSong.path!)
				if FileManager.default.fileExists(atPath: path) {
					//удаляем пропущенный трек
					do{
						try FileManager.default.removeItem(atPath: path)
						
					}
					catch {
						print("Error with remove file ")
					}
                    //удаляем информацию о треке из БД
					CoreDataManager.instance.deleteTrackFor(trackID: self.playingSong.trackID)
					CoreDataManager.instance.saveContext()
				}
			}
		}
        //запускаем следующий трек
		nextTrack(complition: complition)
	}
	
    // проигрываем трек по URL
	func playAudioWith(trackURL:URL) {

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
	
	// selection way to playing (Online or Cache)
	func setWayForPlay(complition: (() -> Void)?) {
		if self.checkCountFileInCache() {
			self.playFromCache(complition: complition)
		} else {
            //проверка подключения к интернету
			guard currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable else {
				return
			}
			Downloader.load {
				
			}
		}
	}
	
    //проверяем есть ли кешированные треки
	func checkCountFileInCache() -> Bool {
		self.canPlayFromCache = false
		if CoreDataManager.instance.getCountOfTracks() > 0 {
			self.canPlayFromCache = true
		}
		return self.canPlayFromCache
	}
	
    // проигрываем трек онлайн
	func playOnline(complition: (() -> Void)?) {
        //проверка подключения к интернету
		guard  currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable  else {
			return
		}
		
        // если есть неотправленная история прослушивания - отправляем
		if CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "HistoryEntity") > 0 {
			CoreDataManager.instance.sentHistory()
		}
        
        //получаем информацию о следующем треке
		ApiService.shared.getTrackIDFromServer {  (dictionary) in
			
			self.playingSong = SongObject()
			
			self.playingSong.initWithDict(dict: dictionary)
			
            //формируем URL трека для проигрывания
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
	
    // проигрываем трек из кеша
	func playFromCache(complition: (() -> Void)?) {
		// если есть неотправленная история прослушивания - отправляем
		if CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "HistoryEntity") > 0 && currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable{
			CoreDataManager.instance.sentHistory()
		}
		
        //получаем из БД трек для проигрывания
		self.playingSong = CoreDataManager.instance.getRandomTrack()
		let docUrl = NSURL(string:FileManager.documentsDir())
		let resUrl = docUrl?.absoluteURL?.appendingPathComponent(playingSong.path!)
		guard let url = resUrl else {
			return
		}
		self.player.pause()
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
	
	//сохраняем историю прослушивания
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
