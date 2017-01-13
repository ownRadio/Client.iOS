//
//  ViewController.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 11/22/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//
// Creation and update UI

import UIKit
import MediaPlayer

class RadioViewController: UIViewController {
	
	// MARK:  Outlets
	
	@IBOutlet weak var backgroundImageView: UIImageView!
	
	@IBOutlet weak var infoView: UIView!
	@IBOutlet weak var circleViewConteiner: UIView!
	
	@IBOutlet weak var trackNameLbl: UILabel!
	@IBOutlet weak var authorNameLbl: UILabel!
	@IBOutlet weak var trackIDLbl: UILabel!
	@IBOutlet weak var deviceIdLbl: UILabel!
	@IBOutlet weak var exceptionLbl: UILabel!
	@IBOutlet var versionLabel: UILabel!
	@IBOutlet var numberOfFiles: UILabel!
	@IBOutlet var numberOfFilesInDB: UILabel!
	@IBOutlet var playFrom: UILabel!
	@IBOutlet var isNowPlaying: UILabel!
	@IBOutlet var portType: UILabel!
	
	@IBOutlet weak var playPauseBtn: UIButton!
	@IBOutlet weak var nextButton: UIButton!
	
	@IBOutlet weak var leftPlayBtnConstraint: NSLayoutConstraint!
	
	// MARK: Variables
	let defaultSession = URLSession(configuration: URLSessionConfiguration.default)
	var dataTask: URLSessionDataTask?
	var player: AudioPlayerManager!
	
	var isPlaying: Bool!
	var visibleInfoView: Bool!
	
	var timer = Timer()
	var timeObserver:AnyObject?
	
	let progressView = CircularView(frame: CGRect.zero)
	
	let playBtnConstraintConstant = CGFloat(15.0)
	let pauseBtnConstraintConstant = CGFloat(10.0)
	
	// MARK: Override
	//выполняется при загрузке окна
	override func viewDidLoad() {
		super.viewDidLoad()
		self.authorNameLbl.text = "ownRadio"
		self.trackNameLbl.text = ""
		//get version of app
		if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
			
			if (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) != nil {
				self.versionLabel.text =  "v" + version
			}
		}
		
		self.circleViewConteiner.addSubview(self.progressView)
		self.progressView.frame = self.circleViewConteiner.bounds
		self.progressView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
		
		self.player = AudioPlayerManager.sharedInstance
		self.detectedHeadphones()
		
		self.deviceIdLbl.text = (UserDefaults.standard.object(forKey: "UUIDDevice") as! String).lowercased()
		self.visibleInfoView = false
		
		DispatchQueue.global(qos: .background).async { [unowned self] in
			self.downloadTracks()
		}
		
		getCountFilesInCache()
		
		//подписываемся на уведомления
		//обрыв воспроизведения трека
		NotificationCenter.default.addObserver(self, selector: #selector(crashNetwork(_:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: self.player.playerItem)
		//трек доигран до конца
		NotificationCenter.default.addObserver(self, selector: #selector(songDidPlay), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
		//обновление системной информации
		NotificationCenter.default.addObserver(self, selector: #selector(updateSysInfo(_:)), name: NSNotification.Name(rawValue:"updateSysInfo"), object: nil)
	}
	
	func detectedHeadphones () {
		
		let currentRoute = AVAudioSession.sharedInstance().currentRoute
		if currentRoute.outputs.count != 0 {
			for description in currentRoute.outputs {
				if description.portType == AVAudioSessionPortHeadphones {
					print("headphone plugged in")
				} else {
					print("headphone pulled out")
				}
			}
		} else {
			print("requires connection to device")
		}
		
		NotificationCenter.default.addObserver(self, selector:  #selector(RadioViewController.audioRouteChangeListener(notification:)), name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
		
	}
	
	//когда приложение скрыто - отписываемся от уведомлений
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player.playerItem)
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil)
	}
	
	//управление проигрыванием со шторки / экрана блокировки
	override func remoteControlReceived(with event: UIEvent?) {
		//по событию нажития на кнопку управления медиаплеером
		//проверяем какая именно кнопка была нажата и обрабатываем нажатие
		if event?.type == UIEventType.remoteControl {
			switch event!.subtype {
			case UIEventSubtype.remoteControlPause:
				changePlayBtnState()
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(self.player.player.currentTime())
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0
				
			case .remoteControlPlay:
				changePlayBtnState()
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(self.player.player.currentTime())
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1
				
			case .remoteControlTogglePlayPause:
				break
				
			case .remoteControlNextTrack:
				player.skipSong(complition: {
					DispatchQueue.main.async { [unowned self] in
						self.updateUI()
					}
				})
			default:
				break
			}
		}
	}
	
	func downloadTracks() {
		guard currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable else {
			return
		}
		Downloader.load() {
			
		}
	}
	
	// MARK: Notification Selectors
	func songDidPlay() {
		self.player.nextTrack { [unowned self] in
			DispatchQueue.main.async {
				self.updateUI()
			}
		}
	}
	
	//функция обновления поля Info системной информации
	func updateSysInfo(_ notification: Notification){
		guard let userInfo = notification.userInfo,
			let message = userInfo["message"] as? String else {
				self.exceptionLbl.text = "No userInfo found in notification"
				return
		}
		self.exceptionLbl.text = message
	}
	
	func crashNetwork(_ notification: Notification) {
		self.playPauseBtn.setImage(UIImage(named: "playImg"), for: UIControlState.normal)
		self.leftPlayBtnConstraint.constant = pauseBtnConstraintConstant
		self.trackIDLbl.text = ""
		self.exceptionLbl.text = notification.description
	}
	
	func audioRouteChangeListener(notification:NSNotification) {
		let audioRouteChangeReason = notification.userInfo![AVAudioSessionRouteChangeReasonKey] as! UInt
		//		 AVAudioSessionPortHeadphones
		switch audioRouteChangeReason {
		case AVAudioSessionRouteChangeReason.newDeviceAvailable.rawValue:
			print("headphone plugged in")
			let currentRoute = AVAudioSession.sharedInstance().currentRoute
			for description in currentRoute.outputs {
				
				self.portType.text = description.portType
				
				if description.portType == AVAudioSessionPortHeadphones {
					print(description.portType)
					print(self.player.isPlaying)
				}else {
					print(description.portType)
				}
			}
		case AVAudioSessionRouteChangeReason.oldDeviceUnavailable.rawValue:
			print("headphone pulled out")
			print(self.player.isPlaying)
			self.player.isPlaying = false
			print(self.player.isPlaying)
			updateUI()
			
		case AVAudioSessionRouteChangeReason.categoryChange.rawValue:
			
			//
			for description in AVAudioSession.sharedInstance().currentRoute.outputs {
				
				self.portType.text = description.portType
				
				switch description.portType {
					
				case AVAudioSessionPortBluetoothA2DP:
					break
				case AVAudioSessionPortBluetoothLE:
					if self.player.isPlaying == false {
						self.player.pauseSong {
							
						}
					}
					
				default: break
				}
			}
			//
			
		default:
			break
		}
	}
	
	//меняет состояние проигрывания и кнопку playPause
	func changePlayBtnState() {
		//если трек проигрывается - ставим на паузу
		if player.isPlaying == true {
			player.pauseSong(complition: { [unowned self] in
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(self.player.player.currentTime())
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0
				DispatchQueue.main.async {
					self.updateUI()
				}
				})
		}else {
			//иначе - возобновляем проигрывание если возможно или начинаем проигрывать новый трек
			player.resumeSong(complition: { [unowned self] in
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(self.player.player.currentTime())
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1
				DispatchQueue.main.async {
					self.updateUI()
				}
				})
		}
	}
	
	//функция отображения количества файлов в кеше
	func getCountFilesInCache () {
		do {
			
			let docUrl = NSURL(string:FileManager.documentsDir()) as! URL
			let directoryContents = try FileManager.default.contentsOfDirectory(at: docUrl, includingPropertiesForKeys: nil, options: [])
			
			let mp3Files = directoryContents.filter{ $0.pathExtension == "mp3" }
			self.numberOfFiles.text = String.init(format:"%d", mp3Files.count)
			
		} catch let error as NSError {
			print(error.localizedDescription)
		}
	}
	
	//обновление UI
	func updateUI() {
		self.trackIDLbl.text = self.player.playingSong.trackID
		self.trackNameLbl.text = self.player.playingSong.name
		self.authorNameLbl.text = self.player.playingSong.artistName
		self.isNowPlaying.text = String(self.player.isPlaying)
		
		//обновляение прогресс бара
		self.timeObserver = self.player.player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1.0, 1) , queue: DispatchQueue.main) { [unowned self] (time) in
			if self.player.isPlaying == true {
				self.progressView.progress = (CGFloat(time.seconds) / CGFloat((self.player.playingSong.trackLength)!))
			}
			} as AnyObject?
		
		//обновление кнопки playPause
		if self.player.isPlaying == false {
			self.playPauseBtn.setImage(UIImage(named: "playImg"), for: UIControlState.normal)
			self.leftPlayBtnConstraint.constant = playBtnConstraintConstant
		} else {
			self.playPauseBtn.setImage(UIImage(named: "pauseImg"), for: UIControlState.normal)
			self.leftPlayBtnConstraint.constant = pauseBtnConstraintConstant
		}
		//обновление источника проигрывания
		if CoreDataManager.instance.getCountOfTracks() > 0 {
			self.playFrom.text = "Cache"
		} else {
			self.playFrom.text = "Cache is empty, please wait for the tracks is load"
		}
		// обновление количевства записей в базе данных
		self.numberOfFilesInDB.text = String(CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "TrackEntity"))
	}
	
	// MARK: Actions
	@IBAction func tripleTapAction(_ sender: AnyObject) {
		if self.infoView.isHidden == true {
			
			self.infoView.isHidden = false
			self.visibleInfoView = false
		}else {
			self.infoView.isHidden = true
			self.visibleInfoView = true
		}
	}
	
	@IBAction func nextTrackButtonPressed() {
		self.player.skipSong { [unowned self] in
			
			DispatchQueue.main.async { [unowned self] in
				self.updateUI()
			}
		}
		self.progressView.configure()
		
		self.timeObserver?.removeTimeObserver
		//		self.player.isPlaying = true
		getCountFilesInCache()
	}
	
	//обработчик нажатий на кнопку play/pause
	@IBAction func playBtnPressed() {
		changePlayBtnState()
		getCountFilesInCache()
//		CoreDataManager.instance.getGroupedTracks()
	}
	
	
	
	
}

