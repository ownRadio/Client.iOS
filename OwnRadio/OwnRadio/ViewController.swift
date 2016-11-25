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
	
	let defaultSession = URLSession(configuration: URLSessionConfiguration.default)
	var dataTask: URLSessionDataTask?
	var player: AudioPlayerManager!
	var isPlaying: Bool!
	var itFirst: Bool!
	let playBtnConstraintConstant = CGFloat(15.0)
	let pauseBtnConstraintConstant = CGFloat(10.0)
	var visibleInfoView: Bool!
	
	let iphone4Size = CGSize.init(width: 320, height: 480)
	let iphone5Size = CGSize.init(width: 320, height: 568)
	let iphone6Size = CGSize.init(width: 375, height: 667)
	let iphone7PlusSize = CGSize.init(width: 414, height: 736)
	let iPadPortraitSize = CGSize.init(width: 768, height: 1024)
	let iPadLandscapeSize = CGSize.init(width: 1024, height: 768)
	let iPadProLandscapeSize = CGSize.init(width: 1366, height: 1024)
	let iPadProPortraitSize = CGSize.init(width: 1024, height: 1366)
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		setBackgroudImage()
		self.player = AudioPlayerManager.sharedInstance
		self.isPlaying = false
		itFirst = true
		
		NotificationCenter.default.addObserver(self, selector: #selector(crashNetwork), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
		
		self.playedTrackID.text = (UserDefaults.standard.object(forKey: "UUIDDevice") as! String)
		self.visibleInfoView = false
		
		
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
	}
	
	func setBackgroudImage() {
		switch UIScreen.main.bounds.size {
		case iphone4Size:
			self.backgroundImageView.image = UIImage(named: "iPhone 4")
		case iphone5Size:
			self.backgroundImageView.image = UIImage(named: "iPhone 5")
		case iphone6Size:
			self.backgroundImageView.image = UIImage(named: "iPhone 7")
		case iphone7PlusSize:
			self.backgroundImageView.image = UIImage(named: "iPhone 7 Plus")
		case iPadPortraitSize:
			self.backgroundImageView.image = UIImage(named: "iPad Portrait")
		case iPadLandscapeSize:
			self.backgroundImageView.image = UIImage(named: "iPad Landscape")
		case iPadProPortraitSize:
			self.backgroundImageView.image = UIImage(named: "iPad Pro Portrait")
		case iPadProLandscapeSize:
			self.backgroundImageView.image = UIImage(named: "iPad Pro Landscape")
		default: break
			
		}
	}
	
	func changePlayBtnState() {

		if isPlaying == true {

			isPlaying = false
			self.playPauseBtn.setImage(UIImage(named: "playImg"), for: UIControlState.normal)
			self.leftPlayBtnConstraint.constant = playBtnConstraintConstant
			player.pauseSong()

		}else {

			isPlaying = true
			self.playPauseBtn.setImage(UIImage(named: "pauseImg"), for: UIControlState.normal)
			self.leftPlayBtnConstraint.constant = pauseBtnConstraintConstant

			player.resumeSong()

		}
		
	}
	
	func crashNetwork() {
		isPlaying = false
		self.playPauseBtn.setImage(UIImage(named: "playImg"), for: UIControlState.normal)
		self.leftPlayBtnConstraint.constant = pauseBtnConstraintConstant
		self.trackIDLbl.text = ""
		
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
				player.nextTrack()
			default:
				break
			}
		}
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	// Actions
	
	
	@IBAction func tripleTapAction(_ sender: AnyObject) {
		if self.visibleInfoView == true {
			self.infoView.isHidden = false
		}else {
			self.infoView.isHidden = true
		}

	}

	@IBAction func nextTrackButtonPressed() {
		self.player.skipSong()
		isPlaying = false
		changePlayBtnState()
		
		self.trackIDLbl.text = player.playingSongID
	}
	
	@IBAction func playBtnPressed() {

		changePlayBtnState()
	}
	
}

