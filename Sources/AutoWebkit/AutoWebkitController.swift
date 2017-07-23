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
	///Called whenever a script is being executed. This is NOT invoked for scripts with no entries.
	func controller(_ controller: AutoWebkitController, willBeginExecuting: AutomationScript)
	
	///Called whenever a script has compelted. This is NOT invoked for scripts with no entries.
	func controller(_ controller: AutoWebkitController, didFinishExecuting: AutomationScript)
	
	///Called whenever a step will be executed.
	func controller(_ controller: AutoWebkitController, willExecuteStep: Scriptable)
	
	//Called whenever a step did complete.
	func controller(_ controller: AutoWebkitController, didCompleteStep: Scriptable)
}

public class AutoWebkitController: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
#if os(iOS) || os(tvOS) || os(watchOS)
	private let superview = UIView()
#elseif os(OSX)
	private let superview = NSView()
#endif
	private let webView: WKWebView
	
	private var context: ScriptContext
	private var originalScript: AutomationScript?
	private var steps: [Scriptable]
	private var stepIndex = -1

	private var isLoading: Bool {
		return context.navigations.isEmpty == false
	}
	
	private var canProcessScript: Bool {
		return context.isLoading == false && context.isRunningStep == false
	}
	
	public var isFinished: Bool {
		return stepIndex + 1 >= steps.count
	}
	
	public weak var delegate: AutoWebkitControllerDelegate?
	
	public required init(providedWebView: WKWebView? = nil) {
		self.webView = providedWebView ?? WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
		
		steps = []
		context = ScriptContext()
		
		super.init()
		
		self.webView.configuration.suppressesIncrementalRendering = true
		self.webView.configuration.userContentController.add(self, name: "bridge")
		self.webView.uiDelegate = self
		self.webView.navigationDelegate = self
		
		if providedWebView == nil {
			superview.addSubview(self.webView)
		}
	}

	open func execute(script: AutomationScript, with context: ScriptContext? = nil) {
		originalScript = script
		self.steps = script.steps
		self.context = context ?? ScriptContext()
		
		processNextStepIfPossible()
	}
	
	open func fetchRawContents(completion: @escaping ((String?, Error?) -> Void)) {
		guard canProcessScript else { return }
		
		webView.evaluateJavaScript("document.documentElement.outerHTML.toString()") { (html, error) in
			completion(html as? String, error)
		}
	}
	
	// MARK: Helpers
	
	private func processNextStepIfPossible() {
		let nextStepIndex = stepIndex + 1
		guard isFinished == false && canProcessScript else { return }
		guard nextStepIndex < steps.count else { return }
		
		let step = steps[nextStepIndex]
		guard step.requiresLoaded == false || (step.requiresLoaded && context.hasLoaded) else { return }
		
		process(step: step, at: nextStepIndex)
	}
	
	private func process(step: Scriptable, at index: Int) {
		if let script = originalScript, index == 0 {
			delegate?.controller(self, willBeginExecuting: script)
		}
		
		stepIndex = index
		execute(step)
	}
	
	private func execute(_ step: Scriptable) {
		delegate?.controller(self, willExecuteStep: step)
		context.isRunningStep = true
		
		step.performAction(with: webView, context: context) { [weak self] (newContext, error, nextSteps) in
			self?.context = newContext
			
			DispatchQueue.main.async {
				if let nextSteps = nextSteps, let weakSelf = self {
					weakSelf.steps.insert(contentsOf: nextSteps, at: weakSelf.stepIndex + 1)
				}
				
				if let error = error {
					print("Error while performing step: \(step) with \(error)")
				}
				
				self?.finish(step)
			}
		}
	}
	
	private func finish(_ step: Scriptable) {
		context.isRunningStep = false
		delegate?.controller(self, didCompleteStep: step)

		if isFinished {
			if let script = originalScript {
				delegate?.controller(self, didFinishExecuting: script)
			}
		}
		else {
			processNextStepIfPossible()
		}
	}
	
	private func attachOnLoadListener() {
		context.hasLoaded = false
		
		//HACK: Since Swift Package Manager doesn't support resources yet, we've manually loaded this into the sourcefile.
		webView.evaluateJavaScript(AutoWebkitController.onLoadScript) { (result, error) in
			if let error = error {
				fatalError("Failed to attach onLoad -- \(error)")
			}
		}
//		if let path = Bundle(for: AutoWebkitController.self).path(forResource: "onLoad", ofType: "js") {
//			do {
//				let javascript = try String(contentsOfFile: path, encoding: .utf8)
//				webView.evaluateJavaScript(javascript) { (result, error) in
//					if let error = error {
//						fatalError("Failed to attach onLoad -- \(error)")
//					}
//					else {
//						print("Attached onLoad")
//					}
//				}
//			}
//			catch let error {
//				fatalError("Failed to attach onLoad -- \(error)")
//			}
//		}
//		else {
//			fatalError("Failed to attach onLoad -- no script present")
//		}
	}
	
	// MARK: WKNavigationDelegate Methods
	
	public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		decisionHandler(.allow)
	}
	
	public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
		decisionHandler(.allow)
	}
	
	public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation) {
		context.navigations.insert(navigation)
	}
	
	public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation) {
		context.navigations.insert(navigation)
	}
	
	public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation, withError error: Error) {
		context.navigations.remove(navigation)
	}
	
	public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation) {
		attachOnLoadListener()
	}
	
	public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
		context.navigations.remove(navigation)
		processNextStepIfPossible()
	}
	
	public func webView(_ webView: WKWebView, didFail navigation: WKNavigation, withError error: Error) {
		context.navigations.remove(navigation)
		processNextStepIfPossible()
	}
	
	// MARK: WKUIDelegate Methods

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
		context.hasLoaded = true
		processNextStepIfPossible()
	}
	
	private static var onLoadScript: String {
		var script = ""
		script += "if (window.addEventListener) { \n"
		script += "  var documentIsReady = function() { \n"
		script += "    window.webkit.messageHandlers.bridge.postMessage(JSON.stringify({ body: \"finishedLoading\" })); \n"
		script += "  }; \n"
		script += "  if (document.readyState === \"complete\") { \n"
		script += "    window.setTimeout(documentIsReady, 0); \n"
		script += "  }"
		script += "  else {"
		script += "    window.addEventListener(\"load\", function() { \n"
		script += "      window.setTimeout(documentIsReady, 0); \n"
		script += "    }); \n"
		script += "  } \n"
		script += "} \n"
		return script
	}
}
