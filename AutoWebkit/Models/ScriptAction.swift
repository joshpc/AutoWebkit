//
//  ScriptAction.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-26.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import UIKit
import WebKit

typealias ScriptableCompletionHandler = ((Error?) -> Void)

///
/// Encompasses a set of actions that the automation script should do
///
protocol Scriptable {
	func performAction(with webView: WKWebView, completion: @escaping ScriptableCompletionHandler)
}

enum ScriptAction: Scriptable {
	case load(url: URL)
	case setAttribute(name: String, value: String?, elementId: String)
	case wait(duration: TimeInterval)
	case submit(formId: String)
	
	case printDebugMessage(message: String)
	
	func performAction(with webView: WKWebView, completion: @escaping ScriptableCompletionHandler) {
		switch self {
		case .load(let url):
			loadUrl(url, with: webView, completion: completion)
		case .wait(let duration):
			waitFor(duration, completion: completion)
		case .submit(let formId):
			submitForm(formId, with: webView, completion: completion)
		case .setAttribute(let name, let value, let elementId):
			updateAttribute(name, value: value, on: elementId, with: webView, completion: completion)
		case .printDebugMessage(let message):
			printMessage(message, completion: completion)
		}
	}
	
	private func loadUrl(_ url: URL, with webView: WKWebView, completion: ScriptableCompletionHandler) {
		webView.load(URLRequest(url: url))
		completion(nil)
	}
	
	private func waitFor(_ duration: TimeInterval, completion: @escaping ScriptableCompletionHandler) {
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + duration) {
			completion(nil)
		}
	}
	
	private func printMessage(_ message: String, completion: ScriptableCompletionHandler) {
		print(message)
		completion(nil)
	}
	
	private func submitForm(_ id: String, with webView: WKWebView, completion: @escaping ScriptableCompletionHandler) {
		//TODO: Consolidate these methods if I can?
		var script = JavascriptUtil.query(id: id)
		script += "element.submit();"
		webView.safelyEvaluateJavaScript(script) { (result, error) in
			completion(error)
		}
	}
	
	private func updateAttribute(_ name: String, value: String?, on elementId: String, with webView: WKWebView, completion: @escaping ScriptableCompletionHandler) {
		var script = JavascriptUtil.query(id: elementId)
		if let value = value {
			script += "element.setAttribute('\(name)', '\(value)');"
		}
		else {
			script += "element.removeAttribute('\(name)');"
		}
		
		webView.safelyEvaluateJavaScript(script) { (result, error) in
			completion(error)
		}
	}
}

fileprivate class JavascriptUtil {
	/// Returns an executable javascript fragment that lets you fetch an element by id, stored in a var named `element`
	class func query(id: String) -> String {
		return "var element = document.querySelector('[id=\"\(id)\"]');"
	}
	
	// Returns an executable javascript fragment that lets you fetch an element by name, stored in var named `element`
	class func query(name: String, tagName: String = "") -> String {
		return "var element = document.querySelector('\(tagName)[name=\"\(name)\"]');"
	}
}

extension WKWebView {
	func safelyEvaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Swift.Void)? = nil) {
		evaluateJavaScript("{ \(javaScriptString) }", completionHandler: completionHandler)
	}
}
