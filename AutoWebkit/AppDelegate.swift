//
//  AppDelegate.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-26.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		let automationController = AutoWebkitController()
		window = UIWindow(frame: UIScreen.main.bounds)
		window?.rootViewController = automationController
		window?.makeKeyAndVisible()
		
		automationController.execute(script: AutomationScript(actions: [
			LoadAction(url: URL(string: "https://www.ramen.ventures/")!),
			WaitAction(waitDuration: 5),
			PrintAction(message: "Hell yeah"),
		]))
		
		return true
	}
}

