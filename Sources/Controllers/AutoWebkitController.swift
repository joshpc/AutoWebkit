//
//  AutoWebkitController.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-26.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
public typealias Controller = UIViewController
#elseif os(OSX)
import AppKit
public typealias Controller = NSViewController
#endif
import WebKit

public protocol AutoWebkitControllerDelegate: NSObjectProtocol {
	func controller(_ controller: AutoWebkitController, willBeginExecuting: AutomationScript)
	func controller(_ controller: AutoWebkitController, didFinishExecuting: AutomationScript)
	
	func controller(_ controller: AutoWebkitController, willExecuteStep: Scriptable)
	func controller(_ controller: AutoWebkitController, didCompleteStep: Scriptable)
}

public class AutoWebkitController: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
	private let configuration: WKWebViewConfiguration
	private let webView: WKWebView
	
	private var navigations = Set<WKNavigation>()
	private var stepIndex = -1
	private var isRunningStep = false
	private var hasLoaded: Bool = false
	
	private var script: AutomationScript?
	
	public weak var delegate: AutoWebkitControllerDelegate?
	
	private var isLoading: Bool {
		return navigations.isEmpty == false
	}
	
	public var isFinished: Bool {
		return stepIndex + 1 >= script?.steps.count ?? 0
	}
	
	public required init(webView: WKWebView? = nil) {
		let configuration = WKWebViewConfiguration()
		self.webView = webView ?? WKWebView(frame: .zero, configuration: configuration)
		self.configuration = configuration
		
		super.init()
		
		configuration.userContentController.add(self, name: "bridge")
		self.webView.uiDelegate = self
		self.webView.navigationDelegate = self
	}

	open func execute(script: AutomationScript) {
		self.script = script
		
		processNextStepIfPossible()
	}
	
	// MARK: Helpers
	
	private func processNextStepIfPossible() {
		let nextStepIndex = stepIndex + 1
		guard isFinished == false, isLoading == false, isRunningStep == false else { return }
		guard let script = script, nextStepIndex < script.steps.count else { return }
		
		let step = script.steps[nextStepIndex]
		if let step = step as? ScriptAction {
			guard step.requiresLoaded == false || (step.requiresLoaded && hasLoaded) else { return }
		}
		
		process(script: script, step: step, at: nextStepIndex)
	}
	
	private func process(script: AutomationScript, step: Scriptable, at index: Int) {
		if index == 0 {
			delegate?.controller(self, willBeginExecuting: script)
		}
		
		stepIndex = index
		execute(step)
	}
	
	private func execute(_ step: Scriptable) {
		delegate?.controller(self, willExecuteStep: step)
		isRunningStep = true
		
		step.performAction(with: webView) { [weak self] (error) in
			if let error = error {
				print("Error while performing step: \(step) with \(error)")
			}
			
			self?.finish(step)
		}
	}
	
	private func finish(_ step: Scriptable) {
		isRunningStep = false
		delegate?.controller(self, didCompleteStep: step)

		guard let script = script else { return }
		
		if isFinished {
			delegate?.controller(self, didFinishExecuting: script)
		}
		else {
			processNextStepIfPossible()
		}
	}
	
	private func attachOnLoadListener() {
		if let path = Bundle.main.path(forResource: "onLoad", ofType: "js") {
			do {
				let javascript = try String(contentsOfFile: path, encoding: .utf8)
				webView.evaluateJavaScript(javascript) { (result, error) in
					if let error = error {
						print("Failed to attach onLoad \(error)")
					}
					else {
						print("Attached onLoad")
					}
				}
			}
			catch let error {
				print("Failed to attach onLoad -- \(error)")
			}
		}
	}
	
	// MARK: WKNavigationDelegate Methods
	
	public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		print("\t navigationAction: \(navigationAction) - \(navigationAction.navigationType)")
		decisionHandler(.allow)
	}
	
	public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
		print("\t navigationResponse: \(navigationResponse)")
		decisionHandler(.allow)
	}
	
	public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation) {
		navigations.insert(navigation)
	}
	
	public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation) {
		//TODO: Test this
		
		print("\(#function) %: \(webView.estimatedProgress)")
		print("\t navigation: \(navigation)")
		print("\n\n")
	}
	
	public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation, withError error: Error) {
		navigations.remove(navigation)
	}
	
	public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation) {
		attachOnLoadListener()
	}
	
	public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
		navigations.remove(navigation)
		
		if hasLoaded == true {
			processNextStepIfPossible()
		}
	}
	
	public func webView(_ webView: WKWebView, didFail navigation: WKNavigation, withError error: Error) {
		navigations.remove(navigation)
		
		if hasLoaded == true {
			processNextStepIfPossible()
		}
	}
	
	// MARK: WKUIDelegate Methods
	
	public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
		print("\(#function) %: \(webView.estimatedProgress)")
		print("\n\n")
		return nil
	}
	
	public func webViewDidClose(_ webView: WKWebView) {
		print("\(#function) %: \(webView.estimatedProgress)")
		print("\n\n")
	}
	
	public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
		completionHandler()
	}
	
	public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
		//TODO: This may be a step that they have to handle
		completionHandler(false)
	}
	
	public func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
		//TODO: This may be a step that they have to handle
		completionHandler(nil)
	}
	
#if os(iOS) || os(tvOS) || os(watchOS)
	public func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKPreviewElementInfo) -> Bool {
		//Previewing is strticly disabled
		return false
	}
#endif
	
	// MARK: WKScriptMessageHandler
	
	public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		hasLoaded = true
		processNextStepIfPossible()
	}
}
