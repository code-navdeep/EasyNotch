//
//  Log.swift
//  EasyNotch
//

import Foundation
import os

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "EasyNotch"

    static let media = Logger(subsystem: subsystem, category: "media")
    static let adapter = Logger(subsystem: subsystem, category: "adapter")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}
