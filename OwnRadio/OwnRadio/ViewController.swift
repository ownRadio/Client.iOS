//
//  ViewController.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 11/22/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
	
	// Outlets
	
	@IBOutlet weak var backgroundImageView: UIImageView!
	@IBOutlet weak var trackNameLbl: UILabel!
	@IBOutlet weak var authorNameLbl: UILabel!
	@IBOutlet weak var trackIDLbl: UILabel!
	@IBOutlet weak var playedTrackID: UILabel!
	@IBOutlet weak var leftPlayBtnConstraint: NSLayoutConstraint!
	@IBOutlet weak var playPauseBtn: UIButton!
	@IBOutlet weak var nextButton: UIButton!
	@IBOutlet weak var infoView: UIView!
	@IBOutlet weak var exceptionLbl: UILabel!
	
	@IBOutlet var timerLabel: UILabel!
	@IBOutlet var versionLabel: UILabel!

	// Variables
	let defaultSession = URLSession(configuration: URLSessionConfiguration.default)
	var dataTask: URLSessionDataTask?
	var player: AudioPlayerManager!
	var isPlaying: Bool!
	var itFirst: Bool!
	let playBtnConstraintConstant = CGFloat(15.0)
	let pauseBtnConstraintConstant = CGFloat(10.0)
	var visibleInfoView: Bool!
	var timer = Timer()
	
	var currentTime = 0.0
	

	override func viewDidLoad() {
		super.viewDidLoad()

		if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {

			if (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) != nil {
				self.versionLabel.text =  "v" + version
			}

		}


		self.player = AudioPlayerManager.sharedInstance
		self.isPlaying = false
		itFirst = true
		
		NotificationCenter.default.addObserver(self, selector: #selector(crashNetwork(_:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(songDidPlay), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
		
		self.playedTrackID.text = (UserDefaults.standard.object(forKey: "UUIDDevice") as! String)
		self.visibleInfoView = false
		
		
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
	}
	
	func songDidPlay() {
		ApiService.shared.saveHistory(trackId: player.playingSongID!, isListen: 1)
		self.player.nextTrack { [unowned self] in
			DispatchQueue.main.async {
				self.updateUI()
			}
		}
	}
	
	func setTime() {

	}
	
	func changePlayBtnState() {

		if currentReachabilityStatus == NSObject.ReachabilityStatus.notReachable {
			self.exceptionLbl.text = "Have not internet connection"
		} else {
		
		if player.isPlaying == true {
			
//			isPlaying = false
			player.pauseSong(complition: {
				DispatchQueue.main.async {
					self.updateUI()
				}
			})

		}else {

//			isPlaying = true
			player.resumeSong(complition: { [unowned self] in
				DispatchQueue.main.async {
				self.updateUI()
					}
			})
		}
		
		}
	}
	
	func crashNetwork(_ notification: Notification) {
		isPlaying = false
		self.playPauseBtn.setImage(UIImage(named: "playImg"), for: UIControlState.normal)
		self.leftPlayBtnConstraint.constant = pauseBtnConstraintConstant
		self.trackIDLbl.text = ""
		self.exceptionLbl.text = notification.description
	}
	
	override func remoteControlReceived(with event: UIEvent?) {
		
		if event?.type == UIEventType.remoteControl {
			switch event!.subtype {
			case UIEventSubtype.remoteControlPause:
				changePlayBtnState()
			case .remoteControlPlay:

				changePlayBtnState()
				
			case .remoteControlTogglePlayPause:
				break
			//				AudioPlayerManager.sharedInstance.playOrPause()
			case .remoteControlNextTrack:
				player.skipSong(complition: { 
					DispatchQueue.main.async {
						self.updateUI()
					}
				})
			default:
				break
			}
		}
	}
	
	func updateUI() {
		self.trackIDLbl.text = self.player.playingSong.trackID
		self.trackNameLbl.text = self.player.playingSong.name
		
		if self.player.isPlaying == false {
			self.playPauseBtn.setImage(UIImage(named: "playImg"), for: UIControlState.normal)
			self.leftPlayBtnConstraint.constant = playBtnConstraintConstant
		} else {
			self.playPauseBtn.setImage(UIImage(named: "pauseImg"), for: UIControlState.normal)
			self.leftPlayBtnConstraint.constant = pauseBtnConstraintConstant

		}
		self.exceptionLbl.text = ""
	}
	
	// Actions
	
	

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
		isPlaying = false 
//		changePlayBtnState()
	}
	
	@IBAction func playBtnPressed() {
		changePlayBtnState()
	}
	
}

