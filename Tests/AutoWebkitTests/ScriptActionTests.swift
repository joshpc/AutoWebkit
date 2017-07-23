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
	var context: ScriptContext!
	
	override func setUp() {
		super.setUp()
		
		context = ScriptContext()
		webView = MockWebview()
		completedExpectation = XCTestExpectation()
	}
	
	// MARK: LoadActions
	
	func testLoadAction() {
		let action = LoadAction.load(url: URL(string: "http://www.banana.com/")!)
		
		action.performAction(with: webView, context: context) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		
		XCTAssertEqual("http://www.banana.com/", webView.attemptedUrl)
	}

	func testLoadHtmlString() {
		let html = "<html><body>banana</body></html>"
		let url = URL(string: "http://www.banana.com/")!
		let action = LoadAction.loadHtml(html: html, baseURL: url)
		
		action.performAction(with: webView, context: context) { (error) in
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		
		XCTAssertEqual(webView.attemptedBody, html)
		XCTAssertEqual(webView.attemptedBaseURL, url)
	}
	
	// MARK: DomActions
	
	func testSetAttributeAction() {
		let action = DomAction.setAttribute(name: "banana", value: "dinosaur", selector: "[id=\"red\"]")
		
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			XCTAssertNil(nextSteps)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"[id=\"red\"]\");element.setAttribute(\'banana\', \'dinosaur\'); }", webView.attemptedJavascript)
	}
	
	func testSetAttributeWithContextAction() {
		let action = DomAction.setAttributeWithContext(name: "banana", contextKey: "dinosaur", selector: "[id=\"red\"]")
		context.environment["dinosaur"] = "coconut"
		
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			XCTAssertNil(nextSteps)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"[id=\"red\"]\");element.setAttribute(\'banana\', \'coconut\'); }", webView.attemptedJavascript)
	}
	
	func testRemoveAttributeAction() {
		let action = DomAction.setAttribute(name: "banana", value: nil, selector: "[id=\"red\"]")
		
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			XCTAssertNil(nextSteps)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"[id=\"red\"]\");element.removeAttribute(\'banana\'); }", webView.attemptedJavascript)
	}
	
	func testRemoveAttributeWithContextAction() {
		let action = DomAction.setAttributeWithContext(name: "banana", contextKey: "not present", selector: "[id=\"red\"]")
		
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			XCTAssertNil(nextSteps)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"[id=\"red\"]\");element.removeAttribute(\'banana\'); }", webView.attemptedJavascript)
	}
	
	func testSubmitAction() {
		var action = DomAction.submit(selector: "form[name=\"banana\"]", shouldBlock: true)
		
		context.hasLoaded = true
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			XCTAssertNil(nextSteps)
			XCTAssertFalse(context.hasLoaded)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"form[name=\"banana\"]\");element.submit(); }", webView.attemptedJavascript)
		
		context.hasLoaded = true
		action = DomAction.submit(selector: "form[name=\"banana\"]", shouldBlock: false)
		
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			XCTAssertNil(nextSteps)
			self.completedExpectation.fulfill()
		}
		XCTAssertTrue(context.hasLoaded)
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"form[name=\"banana\"]\");element.submit(); }", webView.attemptedJavascript)
	}
	
	func testGetHtmlAction() {
		let action = DomAction.getHtml { html, context, error, completion in
			completion(context, error)
		}
		
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			XCTAssertNil(nextSteps)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("document.documentElement.outerHTML.toString();", webView.attemptedJavascript)
	}
	
	func testGetHtmlElementAction() {
		let action = DomAction.getHtmlByElement(selector: "form[name=\"banana\"]") { html, context, error, completion in
			completion(context, error)
		}
		
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			XCTAssertNil(nextSteps)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		XCTAssertEqual("{ var element = document.querySelector(\"form[name=\"banana\"]\");if (element != null) {element.innerHTML.toString();} else { \"\".toString(); } }", webView.attemptedJavascript)
	}
	
	// MARK: WaitActions
	
	func testWaitAction() {
		let action = WaitAction.wait(duration: DispatchTimeInterval.seconds(2))
		
		let startTime = Date()
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			XCTAssertNil(nextSteps)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 3.0))
		let duration = abs(startTime.timeIntervalSinceNow)
		XCTAssertTrue(duration <= 2.15 && duration >= 1.85)
	}
	
	func testWaitForLoaded() {
		let action = WaitAction.waitUntilLoaded { context, completion in
			completion(context, nil)
		}
		
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			XCTAssertNil(nextSteps)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
	}
	
	// MARK: BranchActions
	
	func testIfPresentSuccess() {
		let success: [Scriptable] = [ DebugAction.printMessage(message: "hello"), DebugAction.printMessage(message: "goodbye"), ]
		let failure: [Scriptable] = [ WaitAction.wait(duration: DispatchTimeInterval.seconds(1)) ]
		
		let action = Branch.ifIsPresent(key: "banana", success: success, failure: failure)
		
		var context = self.context!
		context.environment["banana"] = "dinosaur"
		
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			 //We can't do equality checks on Scriptable values so the count differentiation is sufficient in this test
			XCTAssertEqual(2, nextSteps?.count ?? 0)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
	}
	
	func testIfPresentFail() {
		let success: [Scriptable] = [ DebugAction.printMessage(message: "hello"), DebugAction.printMessage(message: "goodbye"), ]
		let failure: [Scriptable] = [ WaitAction.wait(duration: DispatchTimeInterval.seconds(1)) ]
		
		let action = Branch.ifIsPresent(key: "banana", success: success, failure: failure)
	
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			//We can't do equality checks on Scriptable values so the count differentiation is sufficient in this test
			XCTAssertEqual(1, nextSteps?.count ?? 0)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
	}
	
	func testIfEqualSuccess() {
		let success: [Scriptable] = [ DebugAction.printMessage(message: "hello"), DebugAction.printMessage(message: "goodbye"), ]
		let failure: [Scriptable] = [ WaitAction.wait(duration: DispatchTimeInterval.seconds(1)) ]
		
		let action = Branch.ifEquals(key: "banana", value: "12345", success: success, failure: failure)
		
		var context = self.context!
		context.environment["banana"] = "12345"
		
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			//We can't do equality checks on Scriptable values so the count differentiation is sufficient in this test
			XCTAssertEqual(2, nextSteps?.count ?? 0)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
	}
	
	func testIfEqualNotPresent() {
		let success: [Scriptable] = [ DebugAction.printMessage(message: "hello"), DebugAction.printMessage(message: "goodbye"), ]
		let failure: [Scriptable] = [ WaitAction.wait(duration: DispatchTimeInterval.seconds(1)) ]
		
		let action = Branch.ifEquals(key: "banana", value: "12345", success: success, failure: failure)
		
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			//We can't do equality checks on Scriptable values so the count differentiation is sufficient in this test
			XCTAssertEqual(1, nextSteps?.count ?? 0)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
	}
	
	func testIfEqualFailure() {
		let success: [Scriptable] = [ DebugAction.printMessage(message: "hello"), DebugAction.printMessage(message: "goodbye"), ]
		let failure: [Scriptable] = [ WaitAction.wait(duration: DispatchTimeInterval.seconds(1)) ]
		
		let action = Branch.ifEquals(key: "banana", value: "12345", success: success, failure: failure)
		
		var context = self.context!
		context.environment["banana"] = "NOT RIGHT"
		
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			//We can't do equality checks on Scriptable values so the count differentiation is sufficient in this test
			XCTAssertEqual(1, nextSteps?.count ?? 0)
			self.completedExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
	}
	
	// MARK: DebugActions
	
	func testPrintDebugMessage() {
		let action = DebugAction.printMessage(message: "Test")
		
		//We're only testing to ensure that it calls the completion handler
		action.performAction(with: webView, context: context) { (context, error, nextSteps) in
			XCTAssertNil(nextSteps)
			self.completedExpectation.fulfill()
		}
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
	}
}
