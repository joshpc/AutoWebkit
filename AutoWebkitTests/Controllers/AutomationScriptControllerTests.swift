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
}
