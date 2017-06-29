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

public class AutoWebkitController: Controller, WKNavigationDelegate, WKUIDelegate, AutomationScriptControllerDelegate, WKScriptMessageHandler {
	private var scriptController: AutomationScriptController?
	
	private var configuration: WKWebViewConfiguration!
	private var webView: WKWebView!
	private var navigations = Set<WKNavigation>()
	
	private var isScriptRunning = false
	private var hasLoaded: Bool = false
	private var isLoading: Bool {
		return navigations.isEmpty == false
	}
	
	public override func loadView() {
		configuration = WKWebViewConfiguration()
		configuration.userContentController.add(self, name: "bridge")
		webView = WKWebView(frame: .zero, configuration: configuration)
		webView.uiDelegate = self
		webView.navigationDelegate = self
		view = webView
	
		scriptController?.webView = webView
	}
	
#if os(iOS) || os(tvOS) || os(watchOS)
	public override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		processNextStepIfPossible()
	}
#elseif os(OSX)
	public override func viewWillAppear() {
		super.viewWillAppear()
		
		processNextStepIfPossible()
	}
#endif
	
	
	open func execute(script: AutomationScript) {
		scriptController = AutomationScriptController(script: script)
		scriptController?.delegate = self
		scriptController?.webView = webView
		
		processNextStepIfPossible()
	}
	
	// MARK: Helpers
	
	private func processNextStepIfPossible() {
		guard let scriptController = scriptController else { return }
		
		if isScriptRunning == false && isLoading == false && scriptController.isFinished == false {
			scriptController.processNextStep()
		}
	}
	
	// MARK: AutomationScriptControllerDelegate Methods
	
	open func controller(_ controller: AutomationScriptController, willExecute: Scriptable) {
		isScriptRunning = true
	}
	
	open func controller(_ controller: AutomationScriptController, didComplete: Scriptable) {
		isScriptRunning = false
		
		if hasLoaded {
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