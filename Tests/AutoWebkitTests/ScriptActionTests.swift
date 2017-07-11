//
//  ScriptActionTests.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-28.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import XCTest
import WebKit
@testable import AutoWebkit

class MockWebview: WKWebView {
	var attemptedUrl: String?
	var attemptedJavascript: String?
	var attemptedBody: String?
	var attemptedBaseURL: URL?
	
	override func load(_ request: URLRequest) -> WKNavigation? {
		attemptedUrl = request.url?.absoluteString
		return nil
	}
	
	override func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? {
		attemptedBody = string
		attemptedBaseURL = baseURL
		return nil
	}
	
	override func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
		attemptedJavascript = javaScriptString
		completionHandler?(nil, nil)
	}
}

class ScriptActionTests: XCTestCase {
	var webView: MockWebview!
	var completedExpectation: XCTestExpectation!
	var context: [String : String]!
	
	override func setUp() {
		super.setUp()
		
		context = [:]
		webView = MockWebview()
		completedExpectation = XCTestExpectation()
	}
	
	// MARK: LoadActions
	
	func testLoadAction() {
		let action = LoadAction.load(url: URL(string: "http://www.banana.com/")!)
		
		let requiresLoading = action.performAction(with: webView, context: context) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertTrue(requiresLoading)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		
		XCTAssertEqual("http://www.banana.com/", webView.attemptedUrl)
	}

	func testLoadHtmlString() {
		let html = "<html><body>banana</body></html>"
		let url = URL(string: "http://www.banana.com/")!
		let action = LoadAction.loadHtml(html: html, baseURL: url)
		
		let requiresLoading = action.performAction(with: webView, context: context) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertTrue(requiresLoading)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		
		XCTAssertEqual(webView.attemptedBody, html)
		XCTAssertEqual(webView.attemptedBaseURL, url)
	}
	
	// MARK: DomActions
	
	func testSetAttributeAction() {
		let action = DomAction.setAttribute(name: "banana", value: "dinosaur", selector: "[id=\"red\"]")
		
		let requiresLoading = action.performAction(with: webView, context: context) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertFalse(requiresLoading)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"[id=\"red\"]\");element.setAttribute(\'banana\', \'dinosaur\'); }", webView.attemptedJavascript)
	}
	
	func testRemoveAttributeAction() {
		let action = DomAction.setAttribute(name: "banana", value: nil, selector: "[id=\"red\"]")
		
		let requiresLoading = action.performAction(with: webView, context: context) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertFalse(requiresLoading)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"[id=\"red\"]\");element.removeAttribute(\'banana\'); }", webView.attemptedJavascript)
	}
	
	func testSubmitAction() {
		var action = DomAction.submit(selector: "form[name=\"banana\"]", shouldBlock: true)
		
		var requiresLoading = action.performAction(with: webView, context: context) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertTrue(requiresLoading)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"form[name=\"banana\"]\");element.submit(); }", webView.attemptedJavascript)
		
		action = DomAction.submit(selector: "form[name=\"banana\"]", shouldBlock: false)
		
		requiresLoading = action.performAction(with: webView, context: context) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertFalse(requiresLoading)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"form[name=\"banana\"]\");element.submit(); }", webView.attemptedJavascript)
	}
	
	func testGetHtmlAction() {
		let action = DomAction.getHtml { html, context, error, completion in
			completion(context, error)
		}
		
		let requiresLoading = action.performAction(with: webView, context: context) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertFalse(requiresLoading)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("document.documentElement.outerHTML.toString()", webView.attemptedJavascript)
	}
	
	func testGetHtmlElementAction() {
		let action = DomAction.getHtmlByElement(selector: "form[name=\"banana\"]") { html, context, error, completion in
			completion(context, error)
		}
		
		let requiresLoading = action.performAction(with: webView, context: context) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertFalse(requiresLoading)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"form[name=\"banana\"]\");element.innerHTML.toString(); }", webView.attemptedJavascript)
	}
	
	// MARK: WaitActions
	
	func testWaitAction() {
		let action = WaitAction.wait(duration: DispatchTimeInterval.seconds(2))
		
		let startTime = Date()
		let requiresLoading = action.performAction(with: webView, context: context) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertFalse(requiresLoading)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 3.0))
		let duration = abs(startTime.timeIntervalSinceNow)
		XCTAssertTrue(duration <= 2.15 && duration >= 1.85)
	}
	
	func testWaitForLoaded() {
		let action = WaitAction.waitUntilLoaded { completion in
			completion()
		}
		
		let requiresLoading = action.performAction(with: webView, context: context) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertFalse(requiresLoading)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
	}
	
	// MARK: DebugActions
	
	func testPrintDebugMessage() {
		let action = DebugAction.printMessage(message: "Test")
		
		//We're only testing to ensure that it calls the completion handler
		let requiresLoading = action.performAction(with: webView, context: context) { (error) in
			self.completedExpectation.fulfill()
		}
		XCTAssertFalse(requiresLoading)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
	}
}
