//
//  ScriptAction.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-26.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import WebKit

public typealias ScriptContext = [String : String]
public typealias ScriptableCompletionHandler = (ScriptContext, Error?) -> Void
public typealias ScriptActionCallback = (@escaping () -> Void) -> Void
public typealias ScriptHtmlCallback = (String?, ScriptContext, Error?, ScriptableCompletionHandler) -> Void

///
/// Encompasses a set of actions that the automation script should do
///
public protocol Scriptable {
	/// Performs an action, given a specific webview and a completion handler.
	///
	/// Return true if you expect a load action to occur (eventually) and the remainder of the script requires that action to complete.
	func performAction(with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) -> Bool
	
	/// If true, then the entire browser context must be loaded before this action is performed.
	var requiresLoaded: Bool { get }
}

///
/// `LoadActions` allow you to change the browser location, or contents. This is usually done at the beginning of a script, but can be done at any time.
/// This allows you to chain information from multiple pages together, if you so wish.
///
public enum LoadAction: Scriptable {
	case load(url: URL)
	case loadHtml(html: String, baseURL: URL?)
	
	public var requiresLoaded: Bool {
		return false
	}
	
	public func performAction(with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) -> Bool {
		switch self {
		case .load(let url):
			loadUrl(url, with: webView, context: context, completion: completion)
		case .loadHtml(let html, let baseURL):
			loadHtmlString(html, baseURL: baseURL, with: webView, context: context, completion: completion)
		}
		return true
	}
	
	private func loadUrl(_ url: URL, with webView: WKWebView, context: ScriptContext, completion: ScriptableCompletionHandler) {
		webView.load(URLRequest(url: url))
		completion(context, nil)
	}
	
	private func loadHtmlString(_ html: String, baseURL: URL?, with webView: WKWebView, context: ScriptContext, completion: ScriptableCompletionHandler) {
		webView.loadHTMLString(html, baseURL: baseURL)
		completion(context, nil)
	}
}

///
/// A `WaitAction` allows you to pause the execution of the script until certain conditions are met.
///
public enum WaitAction: Scriptable {
	case wait(duration: DispatchTimeInterval)
	case waitUntilLoaded(callback: ScriptActionCallback?)
	
	public var requiresLoaded: Bool {
		switch self {
		case .waitUntilLoaded:
			return true
		default:
			return false
		}
	}
	
	public func performAction(with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) -> Bool {
		switch self {
		case .wait(let duration):
			waitFor(duration, context: context, completion: completion)
		case .waitUntilLoaded(let callback):
			waitForLoadingCompletion(callback: callback, context: context, completion: completion)
		}
		return false
	}
	
	private func waitFor(_ duration: DispatchTimeInterval, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + duration) {
			completion(context, nil)
		}
	}
	
	private func waitForLoadingCompletion(callback: ScriptActionCallback?, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		if let callback = callback {
			callback() {
				completion(context, nil)
			}
		}
		else {
			completion(context, nil)
		}
	}
}

///
/// A `DomAction` allows you to view, or manipulate, the HTML DOM. This currently only supports simple string based interactions
/// (as if you were doing this via the console in a browser).
///
public enum DomAction: Scriptable {
	case setAttribute(name: String, value: String?, selector: String)
	case submit(selector: String, shouldBlock: Bool)
	case getHtml(callback: ScriptHtmlCallback)
	case getHtmlByElement(selector: String, callback: ScriptHtmlCallback)
	
	public var requiresLoaded: Bool {
		return true
	}
	
	public func performAction(with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) -> Bool {
		var requiresLoading = false
		switch self {
		case .setAttribute(let name, let value, let selector):
			updateAttribute(name, value: value, withTagMatching: selector, with: webView, context: context, completion: completion)
		case .submit(let selector, let shouldBlock):
			requiresLoading = shouldBlock
			submitForm(matching: selector, with: webView, context: context, completion: completion)
		case .getHtml(let callback):
			fetchHtml(with: webView, callback: callback, context: context, completion: completion)
		case .getHtmlByElement(let selector, let callback):
			fetchHtmlElement(with: webView, selector: selector, context: context, callback: callback, completion: completion)
		}
		return requiresLoading
	}
	
	private func fetchHtml(with webView: WKWebView, callback: @escaping ScriptHtmlCallback, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		webView.evaluateJavaScript("document.documentElement.outerHTML.toString()", completionHandler: { (html: Any?, error: Error?) in
			callback(html as? String, context, error) { newContext, newError in
				completion(newContext, newError)
			}
		})
	}
	
	private func fetchHtmlElement(with webView: WKWebView, selector: String, context: ScriptContext, callback: @escaping ScriptHtmlCallback, completion: @escaping ScriptableCompletionHandler) {
		var script = JavascriptUtil.createSelector(selector)
		script += "element.innerHTML.toString();"
		webView.safelyEvaluateJavaScript(script) { (result, error) in
			callback(result as? String, context, error) { newContext, newError in
				completion(newContext, newError)
			}
		}
	}
	
	private func submitForm(matching selector: String, with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		//TODO: Consolidate these methods if I can?
		var script = JavascriptUtil.createSelector(selector)
		script += "element.submit();"
		webView.safelyEvaluateJavaScript(script) { (result, error) in
			completion(context, error)
		}
	}
	
	private func updateAttribute(_ name: String, value: String?, withTagMatching selector: String, with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		var script = JavascriptUtil.createSelector(selector)
		if let value = value {
			script += "element.setAttribute('\(name)', '\(value)');"
		}
		else {
			script += "element.removeAttribute('\(name)');"
		}
		
		webView.safelyEvaluateJavaScript(script) { (result, error) in
			completion(context, error)
		}
	}
}

///
/// `DebugAction`s are not recommended for production use, and simply allow you to perform simple debug actions.
///
public enum DebugAction: Scriptable {
	case printMessage(message: String)
	
	public var requiresLoaded: Bool {
		return false
	}
	
	public func performAction(with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) -> Bool {
		switch self {
		case .printMessage(let message):
			print(message)
			completion(context, nil)
		}
		return false
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
