//
//  Item.swift
//  IlliniSpots
//
//  Created by Aidan Andrews on 1/7/25.
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
