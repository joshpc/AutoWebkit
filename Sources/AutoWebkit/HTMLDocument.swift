//
//  HTMLDocument.swift
//  AutoWebkit
//
//  Created by Joshua Tessier on 2017-06-26.
//  Copyright © 2017 Joshua Tessier. All rights reserved.
//

import Foundation
import SwiftSoup

///
/// A simple class representing a web document
///
public class HTMLDocument: NSObject {
	let document: Document
	
	init?(html: String) {
		guard let document = HTMLDocument.parse(html) else { return nil }
		self.document = document
	}
	
	func valueForElement(selector: String) -> String? {
		do {
			return try document.select(selector).first()?.val()
		}
		catch {
			return nil
		}
	}
	
	private class func parse(_ html: String) -> Document? {
		do {
			return try SwiftSoup.parse(html)
		}
		catch Exception.Error(let type, let message) {
			print("Error \(type) message \(message)")
		}
		catch {
			print("error")
		}
		return nil
	}
}
