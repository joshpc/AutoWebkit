//
//  ScriptAction.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-26.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import WebKit

///
/// Represents values that a Scriptable action can pass back to the execution context.
///
/// 1. The `ScriptContext` value represents all values that are shared between steps.
/// 2. The `Error` represents an error that may have occurred during that step.
/// 3. The `[Scriptable]` array represents steps that the Scriptable Action can request to process next, before other actions. This is particularly useful when working with conditional steps.
///
public typealias ScriptableCompletionHandler = (ScriptContext, Error?, [Scriptable]?) -> Void

///
/// A `ScriptActionCallback` is a block to be invoked when the Scriptable action has completed its "out of band" work. In other words, invoke this callback whenever you are ready to continute.
///
public typealias ScriptActionCallback = (ScriptContext, ScriptReturn) -> Void

///
/// A `ScriptHtmlCallback` is a block that returns:
/// 
/// 1. A `String` that represents the HTML requested.
/// 2. The `ScriptContext` which represents all values that are shared between steps.
/// 3. Any `Error` that may have occurred while fetching HTML.
/// 4. A `ScriptReturn` block to be invoked when the action is done handling the returned HTML or Error.
///
public typealias ScriptHtmlCallback = (String?, ScriptContext, Error?, ScriptReturn) -> Void

/// 
/// A `ScriptReturn` is to be invoked whenever a step can perform "out of band work" (such as parsing the HTML, or requesting input from a user). When ready to continue, invoke this block.
///
public typealias ScriptReturn = (ScriptContext, Error?) -> Void

///
/// A `ScriptContext` represents the various state that is used to execute
/// the `AutomationScript`. This context allows us to track loading, navigations
/// and the environment variables set by the script during execution.
///
public struct ScriptContext {
	/// True if there is a step that is currently being executed.
	public var isRunningStep = false
	
	/// The set of navigations being executed by the WKWebView.
	public var navigations = Set<WKNavigation>()
	
	/// A list of environment variables set during the execution of the script.
	public var environment: [String : String] = [:]
	
	/// Represents whether or not the webView has completed loading.
	public var hasLoaded: Bool = false
	
	/// Represents if the WKWebView is actively loading.
	public var isLoading: Bool {
		return navigations.isEmpty == false
	}
}

///
/// Encompasses a set of actions that the automation script should do
///
public protocol Scriptable {
	/// Performs an action, given a specific webview and a completion handler.
	///
	/// If this step spawns additional steps (i.e, in the case of a branch) then return them in an array to be executed sequentially BEFORE any other steps take place.
	func performAction(with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler)
	
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
	
	public func performAction(with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		switch self {
		case .load(let url):
			loadUrl(url, with: webView, context: context, completion: completion)
		case .loadHtml(let html, let baseURL):
			loadHtmlString(html, baseURL: baseURL, with: webView, context: context, completion: completion)
		}
	}
	
	private func loadUrl(_ url: URL, with webView: WKWebView, context: ScriptContext, completion: ScriptableCompletionHandler) {
		webView.load(URLRequest(url: url))
		completion(context, nil, nil)
	}
	
	private func loadHtmlString(_ html: String, baseURL: URL?, with webView: WKWebView, context: ScriptContext, completion: ScriptableCompletionHandler) {
		webView.loadHTMLString(html, baseURL: baseURL)
		completion(context, nil, nil)
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
	
	public func performAction(with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		switch self {
		case .wait(let duration):
			waitFor(duration, context: context, completion: completion)
		case .waitUntilLoaded(let callback):
			waitForLoadingCompletion(callback: callback, context: context, completion: completion)
		}
	}
	
	private func waitFor(_ duration: DispatchTimeInterval, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + duration) {
			completion(context, nil, nil)
		}
	}
	
	private func waitForLoadingCompletion(callback: ScriptActionCallback?, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		if let callback = callback {
			callback(context) { context, error in
				completion(context, error, nil)
			}
		}
		else {
			completion(context, nil, nil)
		}
	}
}

///
/// A `DomAction` allows you to view, or manipulate, the HTML DOM. This currently only supports simple string based interactions
/// (as if you were doing this via the console in a browser).
///
public enum DomAction: Scriptable {
	case setAttribute(name: String, value: String?, selector: String)
	case setAttributeWithContext(name: String, contextKey: String, selector: String)
	case submit(selector: String, shouldBlock: Bool)
	case getHtml(callback: ScriptHtmlCallback)
	case getHtmlByElement(selector: String, callback: ScriptHtmlCallback)
	
	public var requiresLoaded: Bool {
		return true
	}
	
	public func performAction(with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		switch self {
		case .setAttribute(let name, let value, let selector):
			updateAttribute(name, value: value, withTagMatching: selector, with: webView, context: context, completion: completion)
		case .setAttributeWithContext(let name, let contextKey, let selector):
			updateAttribute(name, value: context.environment[contextKey], withTagMatching: selector, with: webView, context: context, completion: completion)
		case .submit(let selector, let shouldBlock):
			var newContext = context
			if shouldBlock == true {
				newContext.hasLoaded = false
			}
			submitForm(matching: selector, with: webView, context: newContext, completion: completion)
		case .getHtml(let callback):
			fetchHtml(with: webView, callback: callback, context: context, completion: completion)
		case .getHtmlByElement(let selector, let callback):
			fetchHtmlElement(with: webView, selector: selector, context: context, callback: callback, completion: completion)
		}
	}
	
	private func fetchHtml(with webView: WKWebView, callback: @escaping ScriptHtmlCallback, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		webView.evaluateJavaScript("document.documentElement.outerHTML.toString()", completionHandler: { (html: Any?, error: Error?) in
			callback(html as? String, context, error) { newContext, newError in
				completion(newContext, newError, nil)
			}
		})
	}
	
	private func fetchHtmlElement(with webView: WKWebView, selector: String, context: ScriptContext, callback: @escaping ScriptHtmlCallback, completion: @escaping ScriptableCompletionHandler) {
		var script = JavascriptUtil.createSelector(selector)
		script += "element.innerHTML.toString();"
		webView.safelyEvaluateJavaScript(script) { (result, error) in
			callback(result as? String, context, error) { newContext, newError in
				completion(newContext, newError, nil)
			}
		}
	}
	
	private func submitForm(matching selector: String, with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		//TODO: Consolidate these methods if I can?
		var script = JavascriptUtil.createSelector(selector)
		script += "element.submit();"
		webView.safelyEvaluateJavaScript(script) { (result, error) in
			completion(context, error, nil)
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
			completion(context, error, nil)
		}
	}
}

///
/// `Branch`es allow us to provide a bit of control within the script to do only certain tasks
/// if absolutely necessary, or, handling bizarre cases.
///
public enum Branch: Scriptable {
	case ifIsPresent(key: String, success: [Scriptable]?, failure: [Scriptable]?)
	case ifEquals(key: String, value: String, success: [Scriptable]?, failure: [Scriptable]?)
	
	public var requiresLoaded: Bool {
		return false
	}
	
	public func performAction(with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		var nextSteps: [Scriptable]?
		switch self {
		case .ifIsPresent(let key, let success, let failure):
			nextSteps = context.environment[key] != nil ? success : failure
		case .ifEquals(let key, let value, let success, let failure):
			nextSteps = context.environment[key] == value ? success : failure
		}
		completion(context, nil, nextSteps)
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
	
	public func performAction(with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		switch self {
		case .printMessage(let message):
			print(message)
			completion(context, nil, nil)
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
