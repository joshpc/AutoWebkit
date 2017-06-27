//
//  AutomationScriptController.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-26.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import UIKit
import WebKit

protocol AutomationScriptControllerDelegate: NSObjectProtocol {
	func controller(_ controller: AutomationScriptController, willExecuteAction: ScriptAction)
	func controller(_ controller: AutomationScriptController, didCompleteAction: ScriptAction)
}

///
/// A controller that executes a script
///
class AutomationScriptController: NSObject {
	private var currentActionIndex = -1
	
	var webView: WKWebView?
	
	let script: AutomationScript
	var currentAction: ScriptAction?
	weak var delegate: AutomationScriptControllerDelegate?
	
	var isFinished: Bool {
		return currentActionIndex + 1 >= script.actions.count
	}
	
	init(script: AutomationScript) {
		self.script = script
	}
	
	func processNextStep() {
		guard let webView = webView else {
			print("Cannot process any steps -- no webview")
			return
		}
		
		let nextActionIndex = currentActionIndex + 1
		guard nextActionIndex < script.actions.count else { return }
		let action = script.actions[nextActionIndex]
		currentActionIndex = nextActionIndex
		
		delegate?.controller(self, willExecuteAction: action)
		action.performAction(with: webView) { [weak self] (error) in
			if let error = error {
				print("Error while performing action: \(error)")
			}
			guard let scriptController = self, let delegate = scriptController.delegate else { return }
			delegate.controller(scriptController, didCompleteAction: action)
		}
	}
}
