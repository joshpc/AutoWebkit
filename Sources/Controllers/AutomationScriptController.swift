//
//  AutomationScriptController.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-26.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import Foundation
import WebKit

public protocol AutomationScriptControllerDelegate: NSObjectProtocol {
	func controller(_ controller: AutomationScriptController, willExecute: Scriptable)
	func controller(_ controller: AutomationScriptController, didComplete: Scriptable)
}

///
/// A controller that executes a script
///
public class AutomationScriptController: NSObject {
	private var currentActionIndex = -1
	
	public var webView: WKWebView?
	
	public let script: AutomationScript
	public weak var delegate: AutomationScriptControllerDelegate?
	
	public var isFinished: Bool {
		return currentActionIndex + 1 >= script.actions.count
	}
	
	public init(script: AutomationScript) {
		self.script = script
	}
	
	public func processNextStep() {
		guard let webView = webView else {
			print("Cannot process any steps -- no webview")
			return
		}
		
		let nextActionIndex = currentActionIndex + 1
		guard nextActionIndex < script.actions.count else { return }
		let action = script.actions[nextActionIndex]
		currentActionIndex = nextActionIndex
		
		delegate?.controller(self, willExecute: action)
		action.performAction(with: webView) { [weak self] (error) in
			if let error = error {
				print("Error while performing action: \(error)")
			}
			guard let scriptController = self, let delegate = scriptController.delegate else { return }
			delegate.controller(scriptController, didComplete: action)
		}
	}
}
