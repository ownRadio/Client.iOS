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
	
	@IBOutlet weak var playPauseBtn: UIButton!
	@IBOutlet weak var nextButton: UIButton!
	
	let defaultSession = URLSession(configuration: URLSessionConfiguration.default)
	var dataTask: URLSessionDataTask?
	var player: AudioPlayerManager!
	var isPlaying: Bool!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		self.player = AudioPlayerManager.sharedInstance
		self.isPlaying = false
	}
	
	func changePlayBtnState() {
		if isPlaying == true {

			isPlaying = false
			self.playPauseBtn.setImage(UIImage(named: "playImg"), for: UIControlState.normal)

			player.pauseSong()

		}else {

			isPlaying = true
			self.playPauseBtn.setImage(UIImage(named: "pauseImg"), for: UIControlState.normal)


			player.resumeSong()

		}
		
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	// Actions
	
	@IBAction func nextTrackButtonPressed() {
		self.player.nextTrack()
		isPlaying = false
		changePlayBtnState()
	}
	
	@IBAction func playBtnPressed() {

		changePlayBtnState()
	}
	
}

