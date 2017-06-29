//
//  AutoWebkitControllerTests.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-28.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import XCTest
#if os(iOS) || os(tvOS) || os(watchOS)
	@testable import AutoWebkit
#else
	@testable import AutoWebkitMacOS
#endif

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
	
	override func setUp() {
		super.setUp()
		
		completedExpectation = XCTestExpectation()
		controller = AutoWebkitController()
		mockDelegate = MockAutoWebkitControllerDelegate(expectation: completedExpectation)
		controller.delegate = mockDelegate
	}
	
	// MARK: Testing Delegate Calls
		
	func testDelegateInvokes() {
		let steps: [ScriptAction] = [
			.printDebugMessage(message: "banana")
		]
		
		controller.execute(script: AutomationScript(steps: steps))
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		
		XCTAssertEqual(1, mockDelegate.willBeginScriptCount)
		XCTAssertEqual(1, mockDelegate.didFinishScriptCount)
		XCTAssertEqual(mockDelegate.willExecuteCallCount, mockDelegate.didCompleteCallCount)
		XCTAssertEqual(1, mockDelegate.willExecuteCallCount)
	}
	
	func testMultipleActions() {
		let steps: [ScriptAction] = [
			.printDebugMessage(message: "banana"),
			.printDebugMessage(message: "dinosaur")
		]
		controller.execute(script: AutomationScript(steps: steps))
		XCTAssertEqual(.completed, XCTWaiter.wait(for: [completedExpectation], timeout: 1.0))
		
		XCTAssertEqual(mockDelegate.willExecuteCallCount, mockDelegate.didCompleteCallCount)
		XCTAssertEqual(2, mockDelegate.willExecuteCallCount)
		XCTAssertEqual(true, controller.isFinished)
	}
	
	func testEmptyScript() {
		let steps: [ScriptAction] = []
		
		controller.execute(script: AutomationScript(steps: steps))
		
		XCTAssertEqual(true, controller.isFinished)
		XCTAssertEqual(mockDelegate.willExecuteCallCount, mockDelegate.didCompleteCallCount)
		XCTAssertEqual(0, mockDelegate.willExecuteCallCount)
	}
	
	func testLoadingHtml() {
		let loadedHtml = "<html><head></head><body><p>dinosaur</p></body></html>"
		let steps: [ScriptAction] = [
			.loadHtml(html: loadedHtml, baseURL: nil),
			.waitUntilLoaded,
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
}
