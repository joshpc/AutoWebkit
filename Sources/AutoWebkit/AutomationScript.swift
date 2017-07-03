//
//  AutomationScript.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-26.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

///
/// Encapsulates a list of actions that should be done
///
public struct AutomationScript {
	public let steps: [Scriptable]
	
	public init(steps: [Scriptable]) {
		self.steps = steps
	}
}
