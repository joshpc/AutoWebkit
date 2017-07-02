//
//  ScriptAction.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-26.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import WebKit

public typealias ScriptableCompletionHandler = ((Error?) -> Void)

///
/// Encompasses a set of actions that the automation script should do
///
public protocol Scriptable {
	func performAction(with webView: WKWebView, completion: @escaping ScriptableCompletionHandler)
}

public enum ScriptAction: Scriptable {
	case load(url: URL)
	case loadHtml(html: String, baseURL: URL?)
	case setAttribute(name: String, value: String?, selector: String)
	case submit(selector: String)
	case wait(duration: DispatchTimeInterval)
	case waitUntilLoaded
	case printDebugMessage(message: String)
	
	public var requiresLoaded: Bool {
		switch self {
		case .printDebugMessage, .wait, .load, .loadHtml:
			return false
		default:
			return true
		}
	}
	
	public func performAction(with webView: WKWebView, completion: @escaping ScriptableCompletionHandler) {
		switch self {
		case .load(let url):
			loadUrl(url, with: webView, completion: completion)
		case .loadHtml(let html, let baseURL):
			loadHtmlString(html, baseURL: baseURL, with: webView, completion: completion)
		case .wait(let duration):
			waitFor(duration, completion: completion)
		case .waitUntilLoaded:
			//Since the `waitUntilLoaded` task `requiresLoaded`, it won't get run. This is effectively a blocker step.
			completion(nil)
		case .submit(let selector):
			submitForm(matching: selector, with: webView, completion: completion)
		case .setAttribute(let name, let value, let selector):
			updateAttribute(name, value: value, withTagMatching: selector, with: webView, completion: completion)
		case .printDebugMessage(let message):
			printMessage(message, completion: completion)
		}
	}
	
	private func loadUrl(_ url: URL, with webView: WKWebView, completion: ScriptableCompletionHandler) {
		webView.load(URLRequest(url: url))
		completion(nil)
	}
	
	private func loadHtmlString(_ html: String, baseURL: URL?, with webView: WKWebView, completion: ScriptableCompletionHandler) {
		webView.loadHTMLString(html, baseURL: baseURL)
		completion(nil)
	}
	
	private func waitFor(_ duration: DispatchTimeInterval, completion: @escaping ScriptableCompletionHandler) {
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + duration) {
			completion(nil)
		}
	}
	
	private func printMessage(_ message: String, completion: ScriptableCompletionHandler) {
		print(message)
		completion(nil)
	}
	
	private func submitForm(matching selector: String, with webView: WKWebView, completion: @escaping ScriptableCompletionHandler) {
		//TODO: Consolidate these methods if I can?
		var script = JavascriptUtil.createSelector(selector)
		script += "element.submit();"
		webView.safelyEvaluateJavaScript(script) { (result, error) in
			completion(error)
		}
	}
	
	private func updateAttribute(_ name: String, value: String?, withTagMatching selector: String, with webView: WKWebView, completion: @escaping ScriptableCompletionHandler) {
		var script = JavascriptUtil.createSelector(selector)
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
	///
	/// Fetches the element that matches `selector`.
	///
	/// @param selector the CSS selector that matches the desired element (i.e  [id='15'])
	///
	class func createSelector(_ selector: String) -> String {
		//TODO: Handle single quotes vs double quotes.
		return "var element = document.querySelector(\"\(selector)\");"
	}
}

fileprivate extension WKWebView {
	func safelyEvaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Swift.Void)? = nil) {
		evaluateJavaScript("{ \(javaScriptString) }", completionHandler: completionHandler)
	}
}
