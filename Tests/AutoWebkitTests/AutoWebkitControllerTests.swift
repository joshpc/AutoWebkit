//
//  AutoWebkitControllerTests.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-28.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import XCTest
import WebKit
@testable import AutoWebkit

class MockNextStepAction: Scriptable {
	let expectation: XCTestExpectation
	
	init(expectation: XCTestExpectation) {
		self.expectation = expectation
	}
	
	func performAction(with webView: WKWebView, context: ScriptContext, completion: @escaping ScriptableCompletionHandler) {
		completion(context, nil, [ WaitAction.waitUntilLoaded { (context, scriptReturn) in
			self.expectation.fulfill()
			scriptReturn(context, nil)
		}])
	}
	
	var requiresLoaded: Bool {
		return false
	}
}

class MockAutoWebkitControllerDelegate: NSObject, AutoWebkitControllerDelegate {
	private let expectation: XCTestExpectation
	
	init(expectation: XCTestExpectation) {
		self.expectation = expectation
	}
	
	var willExecuteCallCount = 0
	var didCompleteCallCount = 0
	var willBeginScriptCount = 0
	var didFinishScriptCount = 0
	
	func controller(_ controller: AutoWebkitController, willBeginExecuting: AutomationScript) {
		willBeginScriptCount += 1
	}
	
	func controller(_ controller: AutoWebkitController, didFinishExecuting: AutomationScript) {
		didFinishScriptCount += 1
		
		expectation.fulfill()
	}
	
	func controller(_ controller: AutoWebkitController, willExecuteStep: Scriptable) {
		willExecuteCallCount += 1
	}
	
	func controller(_ controller: AutoWebkitController, didCompleteStep: Scriptable) {
		didCompleteCallCount += 1
	}
}

class AutoWebkitControllerTests: XCTestCase {
	var mockDelegate: MockAutoWebkitControllerDelegate!
	var controller: AutoWebkitController!
	var completedExpectation: XCTestExpectation!
	var context: ScriptContext!
	
	override func setUp() {
		super.setUp()
		
		completedExpectation = XCTestExpectation()
		controller = AutoWebkitController()
		mockDelegate = MockAutoWebkitControllerDelegate(expectation: completedExpectation)
		context = ScriptContext()
		controller.delegate = mockDelegate
	}
	
	// MARK: Testing Delegate Calls
		
	func testDelegateInvokes() {
		let steps: [Scriptable] = [
			DebugAction.printMessage(message: "banana")
		]
		
		controller.execute(script: AutomationScript(steps: steps), with: context)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		
		XCTAssertEqual(1, mockDelegate.willBeginScriptCount)
		XCTAssertEqual(1, mockDelegate.didFinishScriptCount)
		XCTAssertEqual(mockDelegate.willExecuteCallCount, mockDelegate.didCompleteCallCount)
		XCTAssertEqual(1, mockDelegate.willExecuteCallCount)
	}
	
	func testMultipleActions() {
		let steps: [Scriptable] = [
			DebugAction.printMessage(message: "banana"),
			DebugAction.printMessage(message: "dinosaur")
		]
		controller.execute(script: AutomationScript(steps: steps), with: context)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		
		XCTAssertEqual(mockDelegate.willExecuteCallCount, mockDelegate.didCompleteCallCount)
		XCTAssertEqual(2, mockDelegate.willExecuteCallCount)
		XCTAssertTrue(controller.isFinished)
	}
	
	func testEmptyScript() {
		let steps: [Scriptable] = []
		
		controller.execute(script: AutomationScript(steps: steps), with: context)
		
		XCTAssertTrue(controller.isFinished)
		XCTAssertEqual(mockDelegate.willExecuteCallCount, mockDelegate.didCompleteCallCount)
		XCTAssertEqual(0, mockDelegate.willExecuteCallCount)
	}
	
	//TODO: test using load(url:)
	
	func testLoadingHtml() {
		let loadedHtml = "<html><head></head><body><p>dinosaur</p></body></html>"
		let steps: [Scriptable] = [
			LoadAction.loadHtml(html: loadedHtml, baseURL: nil),
			WaitAction.waitUntilLoaded(callback: nil),
		]
		
		controller.execute(script: AutomationScript(steps: steps))
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 3.0))
		
		let fetchExpectation = XCTestExpectation()
		controller.fetchRawContents { (html, error) in
			XCTAssertNil(error)
			XCTAssertEqual(loadedHtml, html)
			fetchExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [fetchExpectation], timeout: 1.0))
	}
	
	func testJavascriptBasedAction() {
		let loadedHtml = "<html><head></head><body><form><input type=\"text\" id=\"banana\"></form></body></html>"
		let expectedHtml = "<html><head></head><body><form><input type=\"text\" id=\"banana\" value=\"dinosaur\"></form></body></html>"
		
		let steps: [Scriptable] = [
			LoadAction.loadHtml(html: loadedHtml, baseURL: nil),
			DomAction.setAttribute(name: "value", value: "dinosaur", selector: "[id='banana']"),
		]
		
		controller.execute(script: AutomationScript(steps: steps))
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 3.0))
		
		let fetchExpectation = XCTestExpectation()
		controller.fetchRawContents { (html, error) in
			XCTAssertNil(error)
			XCTAssertEqual(expectedHtml, html)
			fetchExpectation.fulfill()
		}
		
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [fetchExpectation], timeout: 1.0))
	}
	
	func testContextIsPassedBetweenElements() {
		let loadedHtml = "<html><head></head><body><form><input type=\"text\" id=\"banana\"></form></body></html>"
		context.environment["should_change_since_context_is_shared"] = "right"
		
		var finalContext: ScriptContext!
		let steps: [Scriptable] = [
			LoadAction.loadHtml(html: loadedHtml, baseURL: nil),
			DomAction.getHtmlByElement(selector: "input[id='banana']") { (html, context, error, completion) in
				context.environment["not there"] = "fake value"
				completion(context, error)
			},
			DomAction.getHtmlByElement(selector: "input[id='banana']") { (html, context, error, completion) in
				context.environment.removeAll()
				completion(context, error)
			},
			DomAction.getHtmlByElement(selector: "input[id='banana']") { (html, context, error, completion) in
				context.environment["banana"] = "apple"
				completion(context, error)
			},
			DomAction.getHtmlByElement(selector: "input[id='banana']") { (html, context, error, completion) in
				context.environment["dinosaur"] = "alive"
				completion(context, error)
			},
			DomAction.getHtmlByElement(selector: "input[id='banana']") { (html, context, error, completion) in
				finalContext = context
				completion(finalContext, error)
			},
		]
		
		controller.execute(script: AutomationScript(steps: steps), with: context)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 3.0))
		XCTAssertEqual("apple", finalContext.environment["banana"])
		XCTAssertEqual("alive", finalContext.environment["dinosaur"])
		XCTAssertNil(finalContext.environment["not there"])
		XCTAssertNil(context.environment["should_change_since_context_is_shared"])
	}
	
	func testIfNextStepsAreReturnedTheyreAddedToTheScript() {
		let nextStepExpectation = XCTestExpectation()
		let lastStepExpectation = XCTestExpectation()
		let steps: [Scriptable] = [
			DebugAction.printMessage(message: "A"),
			MockNextStepAction(expectation: nextStepExpectation),
			DebugAction.printMessage(message: "C"),
			MockNextStepAction(expectation: lastStepExpectation),
		]
		
		context.hasLoaded = true
		controller.execute(script: AutomationScript(steps: steps), with: context)
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation, nextStepExpectation, lastStepExpectation], timeout: 1.0))
	}
}
