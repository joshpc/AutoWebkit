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
	func performAction(with webView: WKWebView, completionHandler: @escaping ((Error?) -> Void))
}

struct LoadAction: ScriptAction {
	let url: URL
	
	func performAction(with webView: WKWebView, completionHandler: @escaping ((Error?) -> Void)) {
		webView.load(URLRequest(url: url))
		completionHandler(nil)
	}
}

struct WaitAction: ScriptAction {
	let waitDuration: TimeInterval
	
	func performAction(with webView: WKWebView, completionHandler: @escaping ((Error?) -> Void)) {
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + waitDuration) {
			completionHandler(nil)
		}
	}
}

struct PrintAction: ScriptAction {
	let message: String
	
	func performAction(with webView: WKWebView, completionHandler: @escaping ((Error?) -> Void)) {
		print(message)
		completionHandler(nil)
	}
}

//TODO: Okay, now that we have a framework, how do we actually set the values? How do we communicate the results back
struct SubmitFormAction: ScriptAction {
	let formId: String?
	let formName: String?
	
	init(formId: String) {
		self.formId = formId
		formName = nil
	}
	
	init (formName: String) {
		self.formName = formName
		formId = nil
	}
	
	func performAction(with webView: WKWebView, completionHandler: @escaping ((Error?) -> Void)) {
		var script: String? = nil
		if let formId = formId {
			script = JavascriptUtil.query(id: formId)
		}
		else if let formName = formName {
			script = JavascriptUtil.query(name: formName, tagName: "form")
		}
			
		if var script = script {
			script += "element.submit();"
			
			webView.safelyEvaluateJavaScript(script) { (result, error) in
				completionHandler(error)
			}
		}
		else {
			completionHandler(NSError(domain: "AutoWebkit", code: 0, userInfo: ["error" : "no formId or formName for SubmitFormAction"]))
		}
	}
}

struct SetAttributeAction: ScriptAction {
	let elementId: String
	let name: String
	let value: String?
	
	func performAction(with webView: WKWebView, completionHandler: @escaping ((Error?) -> Void)) {
		var script = JavascriptUtil.query(id: elementId)
		if let value = value {
			script += "element.setAttribute('\(name)', '\(value)');"
		}
		else {
			script += "element.removeAttribute('\(name)');"
		}
		
		webView.safelyEvaluateJavaScript(script) { (result, error) in
			completionHandler(error)
		}
	}
}

struct EvaluateAction: ScriptAction {
	func performAction(with webView: WKWebView, completionHandler: @escaping ((Error?) -> Void)) {
		
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
