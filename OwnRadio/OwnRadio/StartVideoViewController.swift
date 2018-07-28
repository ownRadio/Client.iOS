//
//  StartVideoViewController.swift
//  OwnRadio
//
//  Created by Alexandra Polunina on 03.08.17.
//  Copyright © 2017 Netvox Lab. All rights reserved.
//

import UIKit
import AVFoundation

class StartVideoViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
	
	static let sharedInstance = StartVideoViewController()
	
	var player: AVPlayer = AVPlayer()
	var playerLayer: AVPlayerLayer!
	
	var thisControl: UIPageControl? = nil
	
	var index: Int = 0
	var countTrying: Int = 0
	var pageViewController: UIPageViewController?
	let contentLabels = ["Автоматическая предзагрузка треков пока есть интернет.","Персональные рекомендации.","Если трек прослушан, значит вам он нравится.",
	                     "Если пропущен, значит не очень ).","Идет предзагрузка, подождите."]
	let errorConnectionText = "Для предзагрузки необходим интернет. Включите интернет и попробуйте снова."
	
	var timer = Timer()
	
	override func viewDidLoad(){
		super.viewDidLoad()
		
		let userDefaults = UserDefaults.standard
		
		//Проверяем в первый ли раз было запущено приложение
		if userDefaults.object(forKey: "isAppAlreadyLaunchedOnce") == nil {
			ApiService.shared.registerDevice()
			userDefaults.set(true, forKey: "isAppAlreadyLaunchedOnce")
			print("Приложение запущено впервые")
		}else{
			print("Приложение уже запускалось на этом устройстве")
			//если приложение уже запускалось на устройстве - не показываем видео-слайдер.
			openMainViewController()
			return
		}
		
		//убираем отступ от навигационной панели
		if(self.responds(to: #selector(setter: automaticallyAdjustsScrollViewInsets))){
			self.automaticallyAdjustsScrollViewInsets = false
		}
		//отключаем отображение навигационной панели
		self.navigationController?.isNavigationBarHidden = true
		
		let path = Bundle.main.path(forResource: "video", ofType: "mp4")
		player = AVPlayer.init(url: URL.init(fileURLWithPath: path!))
		
		playerLayer = AVPlayerLayer(player: player)
		playerLayer.frame = self.view.frame
		playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
		self.view.layer.addSublayer(playerLayer)
		player.seek(to: kCMTimeZero)
		player.play()
		
		createPageViewController()
		setupPageControl()
		
		timerStart()
		
		guard currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable else {
			return
		}
		
		DispatchQueue.global(qos: .background).async {
			Downloader.sharedInstance.load(complition: {
				
			})
		}
	}
	
	
	override var shouldAutorotate: Bool {
		get{
			return false
		}
	}
	
	override var supportedInterfaceOrientations: UIInterfaceOrientationMask{
		get{
			return .portrait
		}
	}
	
	func timerStart() -> Void {
		timer.invalidate()
		timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: "timerUpdate", userInfo: Date(), repeats: true)
	}
	
	func timerUpdate() {
		
		if self.index+1 < contentLabels.count {
			var nextViewController = getItemController(self.index+1);
			if (nextViewController == nil) {
				self.index = 0;
				nextViewController = getItemController(self.index);
			}
			pageViewController?.setViewControllers([nextViewController!], direction: .forward, animated: false, completion: nil)
		} else {
			var nextViewController = getItemController(self.index);
			if (nextViewController == nil) {
				self.index = 0;
				nextViewController = getItemController(self.index);
			}
			pageViewController?.setViewControllers([nextViewController!], direction: .forward, animated: false, completion: nil)
		}
	}
	
	func playVideoBackgroud(){
		if playerLayer != nil {
			player.play()
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}
	
	func playerItemDidReachEnd(_ notification: Notification) {
		player.seek(to: kCMTimeZero)
		player.play()
	}
	
	func createPageViewController() {
		
		let pageController = self.storyboard?.instantiateViewController(withIdentifier: "PageViewController") as! UIPageViewController
		
		pageController.dataSource = self
		
		if contentLabels.count > 0 {
			
			
			let firstController = getItemController(0)!
			let startingViewControllers = [firstController]
			
			pageController.setViewControllers(startingViewControllers, direction: UIPageViewControllerNavigationDirection.forward, animated: false, completion: nil)
		}
		
		pageViewController = pageController
		addChildViewController(pageViewController!)
		self.view.addSubview(pageViewController!.view)
		pageViewController!.didMove(toParentViewController: self)
	}
	
	func setupPageControl() {
		self.view.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 84.2/255)
		
		let appearance = UIPageControl.appearance()
		appearance.pageIndicatorTintColor = UIColor.init(red: 3/255, green: 169/255, blue: 244/255, alpha: 1)
		appearance.currentPageIndicatorTintColor =  UIColor.init(red: 147/255, green: 198/255, blue: 256/255, alpha: 1)
	}
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
		
		let itemController = viewController as! ItemViewController
		
		if itemController.itemIndex > 0 {
			timerStart()
			return getItemController(itemController.itemIndex-1)
		}
		
		return nil
	}
	
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		
		let itemController = viewController as! ItemViewController
		
		if itemController.itemIndex+1 < contentLabels.count {
			timerStart()
			return getItemController(itemController.itemIndex+1)
		}
		
		if itemController.itemIndex+1 >= contentLabels.count && CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "TrackEntity") >= 1 {
			openMainViewController()
			
			return nil
		}
		
		return nil
	}
	
	
	
	func getItemController(_ itemIndex: Int) -> ItemViewController? {
		
		if itemIndex < contentLabels.count {
			
			self.index = itemIndex
			let pageItemController = self.storyboard?.instantiateViewController(withIdentifier: "ItemViewController") as! ItemViewController
			pageItemController.itemIndex = itemIndex
			
			if itemIndex == contentLabels.count-1 {
				if self.countTrying < 3 {
					
					pageItemController.isIndicatorHide = false
					pageItemController.isCountTryingHide = false
					//если при открытии последнего слайда треки еще не загрузились -
					//при наличии интернет подключения запускаем загрузку трех треков
					if CoreDataManager.instance.chekCountOfEntitiesFor(entityName: "TrackEntity") < 1 {
						guard currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable else {
							pageItemController.isBtnHide = false
							pageItemController.isIndicatorHide = true
							pageItemController.isCountTryingHide = true
							//если подключение отсутствует - выводим соответствующий текст
							pageItemController.labelText = errorConnectionText
							return pageItemController
						}
						
						self.countTrying += 1
						pageItemController.countTrying = self.countTrying
						
						DispatchQueue.global(qos: .background).async {
							Downloader.sharedInstance.load(complition: {
								
							})
						}
					} else {
						//останавливаем автоскролл слайдов
						timer.invalidate()
						
						pageItemController.isIndicatorHide = true
						
						openMainViewController()
						
						pageItemController.labelText = contentLabels[itemIndex]
						return pageItemController
					}
				} else {
					timer.invalidate()
					self.countTrying = 0
					pageItemController.countTrying = 0
					pageItemController.isBtnHide = false
					pageItemController.isIndicatorHide = true
					pageItemController.isCountTryingHide = true
					//если подключение отсутствует - выводим соответствующий текст
					pageItemController.labelText = errorConnectionText
					return pageItemController
				}
				
			} else {
				pageItemController.isBtnHide = true
				pageItemController.isIndicatorHide = true
				pageItemController.isCountTryingHide = true
			}
			
			pageItemController.labelText = contentLabels[itemIndex]
			return pageItemController
		}
		
		return nil
		
	}
	
	//возвращает заголовок слайда по индексу
	func getContentLblByIndex(index: Int) -> String {
		if index < contentLabels.count {
			return contentLabels[index]
		} else {
			return ""
		}
	}
	
	//открывает основной контроллер проигрывателя
	func openMainViewController() -> Void {
		print("\(self.index)")
		player.pause()
		playerLayer = nil
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		let viewController = storyboard.instantiateViewController(withIdentifier: "RadioViewController")
		navigationController?.pushViewController(viewController, animated: false)
	}
}
