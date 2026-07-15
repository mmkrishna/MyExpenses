//
//  Item.swift
//  MyExpenses+
//
//  Created by Murali Krishna on 15/07/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
