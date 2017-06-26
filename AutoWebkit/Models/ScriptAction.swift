//
//  ScriptAction.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-26.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import UIKit
import WebKit

///
/// Encompasses a set of actions that the automation script should do
///
protocol ScriptAction {
	func performAction(with webView: WKWebView, completionHandler: @escaping ((Void) -> Void))
}

struct LoadAction: ScriptAction {
	let url: URL
	
	func performAction(with webView: WKWebView, completionHandler: @escaping ((Void) -> Void)) {
		webView.load(URLRequest(url: url))
		completionHandler()
	}
}

struct WaitAction: ScriptAction {
	let waitDuration: TimeInterval
	
	func performAction(with webView: WKWebView, completionHandler: @escaping ((Void) -> Void)) {
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + waitDuration, execute: completionHandler)
	}
}

struct PrintAction: ScriptAction {
	let message: String
	
	func performAction(with webView: WKWebView, completionHandler: @escaping ((Void) -> Void)) {
		print(message)
		completionHandler()
	}
}
