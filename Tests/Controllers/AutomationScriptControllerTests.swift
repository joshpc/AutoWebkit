//
//  AutomationScriptControllerTests.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-28.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import XCTest
import WebKit
@testable import AutoWebkit

class MockAutomationScriptControllerDelegate: NSObject, AutomationScriptControllerDelegate {
	var willExecuteCallCount = 0
	var didCompleteCallCount = 0
	
	func controller(_ controller: AutomationScriptController, willExecute: Scriptable) {
		willExecuteCallCount += 1
	}
	
	func controller(_ controller: AutomationScriptController, didComplete: Scriptable) {
		didCompleteCallCount += 1
	}
}

class AutomationScriptControllerTests: XCTestCase {
	var mockDelegate: MockAutomationScriptControllerDelegate!
	
	override func setUp() {
		super.setUp()
		
		mockDelegate = MockAutomationScriptControllerDelegate()
	}
    
	func testDelegateInvokes() {
		let actions: [ScriptAction] = [
			.printDebugMessage(message: "banana")
		]
		let controller = AutomationScriptController(script: AutomationScript(actions: actions))		
		controller.delegate = mockDelegate
		controller.webView = WKWebView()
		controller.processNextStep()
		XCTAssertEqual(mockDelegate.willExecuteCallCount, mockDelegate.didCompleteCallCount)
		XCTAssertEqual(1, mockDelegate.willExecuteCallCount)
	}
	
	func testMultipleActions() {
		let actions: [ScriptAction] = [
			.printDebugMessage(message: "banana"),
			.printDebugMessage(message: "dinosaur")
		]
		let controller = AutomationScriptController(script: AutomationScript(actions: actions))
		XCTAssertEqual(false, controller.isFinished)
		
		controller.delegate = mockDelegate
		controller.webView = WKWebView()
		controller.processNextStep()
		controller.processNextStep()
		XCTAssertEqual(mockDelegate.willExecuteCallCount, mockDelegate.didCompleteCallCount)
		XCTAssertEqual(2, mockDelegate.willExecuteCallCount)
		XCTAssertEqual(true, controller.isFinished)
	}
	
	func testEmptyScript() {
		let actions: [ScriptAction] = []
		
		let controller = AutomationScriptController(script: AutomationScript(actions: actions))
		
		//Finished by default
		XCTAssertEqual(true, controller.isFinished)
		
		controller.delegate = mockDelegate
		controller.webView = WKWebView()
		
		controller.processNextStep()
		controller.processNextStep()
		
		XCTAssertEqual(mockDelegate.willExecuteCallCount, mockDelegate.didCompleteCallCount)
		XCTAssertEqual(0, mockDelegate.willExecuteCallCount)
		XCTAssertEqual(true, controller.isFinished)
	}
}
