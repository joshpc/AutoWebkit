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
			ScriptAction.load(url: URL(string: "https://www.google.ca/")!),
			ScriptAction.setAttribute(name: "value", value: "banana", elementId: "lst-ib"),
			ScriptAction.submit(formId: "tsf")
		]))
		
		return true
	}
}

