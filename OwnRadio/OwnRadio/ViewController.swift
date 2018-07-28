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
import Alamofire

protocol controlsAudio {
	func remoteControlReceived(with event: UIEvent?)
}

class RadioViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, controlsAudio {
	
	// MARK:  Outlets
	@IBOutlet weak var backgroundImageView: UIImageView!
	
	@IBOutlet weak var infoView: UIView!
	@IBOutlet weak var circleViewConteiner: UIView!
    @IBOutlet weak var progressView: UIProgressView!
	
	@IBOutlet weak var freeSpaceLbl:UILabel!
	@IBOutlet weak var folderSpaceLbl: UILabel!
	
	@IBOutlet weak var trackNameLbl: UILabel!
	@IBOutlet weak var authorNameLbl: UILabel!
	@IBOutlet weak var trackIDLbl: UILabel!
	@IBOutlet weak var deviceIdLbl: UILabel!
	@IBOutlet weak var infoLabel1: UILabel!
	@IBOutlet weak var infoLabel2: UILabel!
	@IBOutlet weak var infoLabel3: UILabel!
	@IBOutlet var versionLabel: UILabel!
	@IBOutlet var numberOfFiles: UILabel!
	@IBOutlet var numberOfFilesInDB: UILabel!
	@IBOutlet var isNowPlaying: UILabel!
	@IBOutlet var tableView: UITableView!
	
	@IBOutlet weak var playPauseBtn: UIButton!
	@IBOutlet weak var nextButton: UIButton!
	
	@IBOutlet weak var leftPlayBtnConstraint: NSLayoutConstraint!
	
	// MARK: Variables
	let defaultSession = URLSession(configuration: URLSessionConfiguration.default)
	var dataTask: URLSessionDataTask?
	var player: AudioPlayerManager!
	
	var isPlaying: Bool!
	var visibleInfoView: Bool!
    var isStartListening: Bool! = false
	
	var timer = Timer()
	var timeObserverToken:AnyObject? = nil
	
	//let progressView = CircularView(frame: CGRect.zero)
	
	let playBtnConstraintConstant = CGFloat(15.0)
	let pauseBtnConstraintConstant = CGFloat(10.0)
	
	var cachingView = CachingView.instanceFromNib()
	var playedTracks: NSArray = CoreDataManager.instance.getGroupedTracks()
	var reachability = NetworkReachabilityManager(host: "http://api.ownradio.ru/v5")
	
	let tracksUrlString =  FileManager.applicationSupportDir().appending("/Tracks/")
	
	// MARK: Override
	//выполняется при загрузке окна
	override func viewDidLoad() {
		super.viewDidLoad()
		
		//включаем отображение навигационной панели
		self.navigationController?.isNavigationBarHidden = false
		
		//задаем цвет навигационного бара
		self.navigationController?.navigationBar.barTintColor = UIColor(red: 3.0/255.0, green: 169.0/255.0, blue: 244.0/255.0, alpha: 1.0)
		//цвет кнопки и иконки
		self.navigationController?.navigationBar.tintColor = UIColor.white
		//цвет заголовка
		self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName : UIColor.white]
		
//        if isStartListening == false {
//            self.authorNameLbl.text = "ownRadio"
//        }
		self.trackNameLbl.text = ""
        self.authorNameLbl.text = ""
        
		self.checkMemoryWarning()
		
		cachingView.frame = self.view.bounds
		
		
		
		//get version of app
		if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
			if (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) != nil {
				self.versionLabel.text =  "v" + version
			}
		}
		//self.circleViewConteiner.addSubview(self.progressView)
		//self.progressView.frame = self.circleViewConteiner.bounds
		//self.circleViewConteiner.autoresizingMask = [.flexibleWidth,.flexibleHeight]
		
		self.player = AudioPlayerManager.sharedInstance
		self.detectedHeadphones()
		
		self.deviceIdLbl.text = UIDevice.current.identifierForVendor?.uuidString.lowercased() //  NSUUID().uuidString.lowercased()
		self.visibleInfoView = false
		
		getCountFilesInCache()
	
		//подписываемся на уведомлени
		reachability?.listener = { [unowned self] status in
			guard CoreDataManager.instance.getCountOfTracks() < 1 else {
					self.updateUI()
				return
			}
            if status != NetworkReachabilityManager.NetworkReachabilityStatus.notReachable {
                self.downloadTracks()
            }
		}
		reachability?.startListening()
		self.updateUI()
		//обрыв воспроизведения трека
		NotificationCenter.default.addObserver(self, selector: #selector(crashNetwork(_:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: self.player.playerItem)
		//трек доигран до конца
		NotificationCenter.default.addObserver(self, selector: #selector(songDidPlay), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
		//обновление системной информации
		NotificationCenter.default.addObserver(self, selector: #selector(updateSysInfo(_:)), name: NSNotification.Name(rawValue:"updateSysInfo"), object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(AudioPlayerManager.sharedInstance.onAudioSessionEvent(_:)), name: Notification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
//		//
//		NotificationCenter.default.addObserver(self, selector: #selector(updateUIAfterCleanCache(_:)), name: NSNotification.Name(rawValue:"updateUIAfterCleanCache"), object:
	}
//	override var shouldAutorotate: Bool {
//		get{
//			return false
//		}
//	}
//	
//	override var supportedInterfaceOrientations: UIInterfaceOrientationMask{
//		get{
//			return .portrait
//		}
//	}
	
	func checkMemoryWarning() {
		guard DiskStatus.freeDiskSpaceInBytes < 104857600 && CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "TrackEntity") < 1 else {
			return
		}
		self.authorNameLbl.text = "Not enough free memory. To work correctly, you need at least 100 mb"
		self.trackNameLbl.text = ""
		self.playPauseBtn.isEnabled = false
		self.nextButton.isEnabled = false
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
//		reachability?.stopListening()
		
		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player.playerItem)
//		NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil)
		print("viewDidDisappear")
	}
	
	//управление проигрыванием со шторки / экрана блокировки
	override func remoteControlReceived(with event: UIEvent?) {
		//по событию нажития на кнопку управления медиаплеером
		//проверяем какая именно кнопка была нажата и обрабатываем нажатие
		if event?.type == UIEventType.remoteControl {
			switch event!.subtype {
			case UIEventSubtype.remoteControlPause:
				guard MPNowPlayingInfoCenter.default().nowPlayingInfo != nil else {
					break
				}
				changePlayBtnState()
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(self.player.player.currentTime())
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0
				
			case .remoteControlPlay:
				guard MPNowPlayingInfoCenter.default().nowPlayingInfo != nil else {
					break
				}
				changePlayBtnState()
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(self.player.player.currentTime())
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1
				
			case .remoteControlTogglePlayPause:
				guard MPNowPlayingInfoCenter.default().nowPlayingInfo != nil else {
					break
				}
				changePlayBtnState()
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(self.player.player.currentTime())
				if player.isPlaying == false {
					MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0
				} else {
					MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1
				}
				break
				
			case .remoteControlNextTrack:
				player.skipSong(complition: { [unowned self] in
						self.updateUI()
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
		DispatchQueue.global(qos: .background).async {
			Downloader.sharedInstance.load { [unowned self] in
					self.updateUI()
			}
		}
	}
	
	// MARK: Notification Selectors
	func songDidPlay() {
		self.player.nextTrack { [unowned self] in
				self.updateUI()
		}
//		self.progressView.isHidden = true
	}
	
	//функция обновления поля Info системной информации
	func updateSysInfo(_ notification: Notification){
		DispatchQueue.main.async {
			let creatinDate = Date()
			let dateFormatter = DateFormatter()
			dateFormatter.dateFormat = "H:m:s"//dd.MM.yy 
			dateFormatter.timeZone = TimeZone.current
			let creationDateString = dateFormatter.string(from: creatinDate)
			
			guard let userInfo = notification.userInfo,
				let message = userInfo["message"] as? String else {
					self.infoLabel3.text = self.infoLabel2.text
					self.infoLabel2.text = self.infoLabel1.text
					self.infoLabel1.text = creationDateString + " No userInfo found in notification"
					return
			}
			self.infoLabel3.text = self.infoLabel2.text
			self.infoLabel2.text = self.infoLabel1.text
			self.infoLabel1.text = creationDateString + " " + message
		}
	}
	
	func crashNetwork(_ notification: Notification) {
		self.playPauseBtn.setImage(UIImage(named: "playImg"), for: UIControlState.normal)
		self.leftPlayBtnConstraint.constant = pauseBtnConstraintConstant
		self.trackIDLbl.text = ""
		self.infoLabel3.text = self.infoLabel2.text
		self.infoLabel2.text = self.infoLabel1.text
		self.infoLabel1.text = notification.description
	}
	
	func audioRouteChangeListener(notification:NSNotification) {
		let audioRouteChangeReason = notification.userInfo![AVAudioSessionRouteChangeReasonKey] as! UInt
		//		 AVAudioSessionPortHeadphones
		switch audioRouteChangeReason {
		case AVAudioSessionRouteChangeReason.newDeviceAvailable.rawValue:
			print("headphone plugged in")
			let currentRoute = AVAudioSession.sharedInstance().currentRoute
			for description in currentRoute.outputs {
				
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
			
			for description in AVAudioSession.sharedInstance().currentRoute.outputs {
				
				switch description.portType {
				case AVAudioSessionPortBluetoothA2DP:
					if self.player.isPlaying == false {
						self.player.pauseSong {
						}
					}
				case AVAudioSessionPortBluetoothLE:
					if self.player.isPlaying == false {
						self.player.pauseSong {
						}
					}
				default: break
				}
			}
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
					self.updateUI()
				})
		}else {
			//иначе - возобновляем проигрывание если возможно или начинаем проигрывать новый трек
			player.resumeSong(complition: { [unowned self] in
                if CoreDataManager.instance.getCountOfTracks() > 0 {
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(self.player.player.currentTime())
				MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1
					self.updateUI()
                }
				})
		}
	}
	
	//функция отображения количества файлов в кеше
	func getCountFilesInCache () {
		do {
//			let appSupportUrl = URL(string: FileManager.applicationSupportDir().appending("/"))
			let docUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Tracks")
			let directoryContents = try FileManager.default.contentsOfDirectory(at: docUrl!, includingPropertiesForKeys: nil, options: [])
			let mp3Files = directoryContents.filter{ $0.pathExtension == "mp3" }
			self.numberOfFiles.text = String(CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "TrackEntity"))
		} catch let error as NSError {
			print(error.localizedDescription)
		}
	}
	
	//обновление UI
	func updateUI() {
		DispatchQueue.main.async { [unowned self] in
        
        if self.isStartListening == true {
            self.trackNameLbl.text = self.player.playingSong.name
            self.authorNameLbl.text = self.player.playingSong.artistName
        }
		self.trackIDLbl.text = self.player.playingSong.trackID
		self.isNowPlaying.text = String(self.player.isPlaying)
		
		if CoreDataManager.instance.getCountOfTracks() < 3 && CoreDataManager.instance.getCountOfTracks() != 0 {
//			self.playPauseBtn.isEnabled = false
			self.nextButton.isEnabled = false
			self.cachingView.removeFromSuperview()
		}else if CoreDataManager.instance.getCountOfTracks() < 1 {
			self.playPauseBtn.isEnabled = true
			self.view.addSubview(self.cachingView)
		}else {
			self.playPauseBtn.isEnabled = true
			self.nextButton.isEnabled = true
			self.cachingView.removeFromSuperview()
		}
		
		//обновляение прогресс бара
		

		//		self.timeObserverToken =
		 self.timeObserverToken = self.player.player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1.0, 1) , queue: DispatchQueue.main) { [unowned self] (time) in
            if self.player.isPlaying == true {
                if self.player.playingSong.trackLength != nil{
                self.progressView.setProgress(Float(CGFloat(time.seconds) / CGFloat((self.player.playingSong.trackLength)!)), animated: false)
					UserDefaults.standard.set(time.seconds.description, forKey:"lastTrackPosition")
					UserDefaults.standard.set(self.player.playingSong.trackID as String, forKey:"lastTrack")
					UserDefaults.standard.synchronize()
					
//					print("trackid = \(self.player.playingSong.trackID)")
//					print(UserDefaults.standard.object(forKey: "lastTrack") ?? "lastTracks")
//					print(UserDefaults.standard.object(forKey: "lastTrackPosition") ?? "lastTrackPositionlk")
					
//					print("progress is \(time.seconds) from \(self.player.playingSong.trackLength)")
//				self.progressView.progress = (CGFloat(time.seconds) / CGFloat((self.player.playingSong.trackLength)!))
                }
			}
			} as AnyObject?
		
		//обновление кнопки playPause
		if self.player.isPlaying == false {
			self.playPauseBtn.setImage(UIImage(named: "playImg"), for: UIControlState.normal)
			//self.leftPlayBtnConstraint.constant = self.playBtnConstraintConstant
		} else {
			self.playPauseBtn.setImage(UIImage(named: "pauseImg"), for: UIControlState.normal)
			//self.leftPlayBtnConstraint.constant = self.pauseBtnConstraintConstant
		}
		
		self.getCountFilesInCache()
		// обновление количевства записей в базе данных
		self.numberOfFilesInDB.text = String(CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "TrackEntity"))
		// update table 
		self.playedTracks = CoreDataManager.instance.getGroupedTracks()
		self.tableView.reloadData()
		
		self.freeSpaceLbl.text = DiskStatus.GBFormatter(Int64(DiskStatus.freeDiskSpaceInBytes)) + " Gb"
		self.folderSpaceLbl.text = DiskStatus.GBFormatter(Int64(DiskStatus.folderSize(folderPath: self.tracksUrlString))) + " Gb"
		
	}
	}
	
	// MARK: UITableViewDataSource
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.playedTracks.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
		
		let dict = playedTracks[indexPath.row] as! [String: Any]
		let countOfPlay = dict["countPlay"] as? Int
		let countOfTracks = dict["count"] as? Int
		if countOfPlay != nil && countOfTracks != nil {
			let str = NSString(format: "Count play: %d - Count tracks: %d", countOfPlay! , countOfTracks! )
			cell.textLabel?.text = str as String
		}
		return cell
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
        isStartListening = true
        
		if player.isPlaying == true {
			self.player.player.pause()
		}
//		self.progressView.isHidden = true
		self.progressView.setProgress(0.0, animated: false)
        
		self.player.skipSong { [unowned self] in
				self.updateUI()
		}
		if self.timeObserverToken != nil {
			self.timeObserverToken = nil
		}
	}
	
	//обработчик нажатий на кнопку play/pause
	@IBAction func playBtnPressed() {
        isStartListening = true
        
		guard self.player.playerItem != nil else {
			
			self.player.isPlaying = true
			nextTrackButtonPressed()
			return
		}
		self.progressView.isHidden = false
		changePlayBtnState()
	}

	@IBAction func refreshPressed() {
		updateUI()
	}
	
	@IBAction func skipTrackToEnd(_ sender: UIButton) {
		self.player.fwdTrackToEnd()
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let dest = segue.destination as? SettingsViewController {
			dest.controlsAudioDelegat = self
		}
	}
	
//	func updateUIAfterCleanCache(_ notification: Notification){
//		DispatchQueue.main.async {
//
////				guard let userInfo = notification.userInfo,
////					let message = userInfo["message"] as? String else
//			
//			if CoreDataManager.instance.getCountOfTracks() < 1 {
//				self.view.addSubview(self.cachingView)
//			}
//		}
//	}
	
}

