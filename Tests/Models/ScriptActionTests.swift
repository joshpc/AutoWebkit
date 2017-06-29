//
//  ScriptActionTests.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-28.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import XCTest
import WebKit
#if os(iOS) || os(tvOS) || os(watchOS)
	@testable import AutoWebkit
#else
	@testable import AutoWebkitMacOS
#endif


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
	
	override func setUp() {
		super.setUp()
		
		webView = MockWebview()
		completedExpectation = XCTestExpectation()
	}
	
	func testLoadAction() {
		let action = ScriptAction.load(url: URL(string: "http://www.banana.com/")!)
		
		action.performAction(with: webView) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("http://www.banana.com/", webView.attemptedUrl)
	}

	func testLoadHtmlString() {
		let html = "<html><body>banana</body></html>"
		let url = URL(string: "http://www.banana.com/")!
		let action = ScriptAction.loadHtml(html: html, baseURL: url)
		
		action.performAction(with: webView) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		
		XCTAssertEqual(webView.attemptedBody, html)
		XCTAssertEqual(webView.attemptedBaseURL, url)
	}
	
	func testSetAttributeAction() {
		let action = ScriptAction.setAttribute(name: "banana", value: "dinosaur", selector: "[id=\"red\"]")
		
		action.performAction(with: webView) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"[id=\"red\"]\");element.setAttribute(\'banana\', \'dinosaur\'); }", webView.attemptedJavascript)
	}
	
	func testRemoveAttributeAction() {
		let action = ScriptAction.setAttribute(name: "banana", value: nil, selector: "[id=\"red\"]")
		
		action.performAction(with: webView) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"[id=\"red\"]\");element.removeAttribute(\'banana\'); }", webView.attemptedJavascript)
	}
	
	func testSubmitAction() {
		let action = ScriptAction.submit(selector: "form[name=\"banana\"]")
		
		action.performAction(with: webView) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"form[name=\"banana\"]\");element.submit(); }", webView.attemptedJavascript)
	}
	
	func testWaitAction() {
		let action = ScriptAction.wait(duration: DispatchTimeInterval.seconds(2))
		
		let startTime = Date()
		action.performAction(with: webView) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 3.0))
		let duration = abs(startTime.timeIntervalSinceNow)
		XCTAssertTrue(duration <= 2.15 && duration >= 1.85)
	}
	
	func testPrintDebugMessage() {
		let action = ScriptAction.printDebugMessage(message: "Test")
		
		//We're only testing to ensure that it calls the completion handler
		action.performAction(with: webView) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
	}
}
