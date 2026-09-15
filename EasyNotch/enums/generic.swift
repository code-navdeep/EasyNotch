//
//  generic.swift
//  EasyNotch
//

import Foundation
import Defaults

public enum NotchState {
    case closed
    case open
}

public enum NotchViews {
    case home
    case lyrics
}

enum WindowHeightMode: String, Defaults.Serializable {
    case matchMenuBar = "Match menubar height"
    case matchRealNotchSize = "Match real notch height"
    case custom = "Custom height"
}

enum SliderColorEnum: String, CaseIterable, Defaults.Serializable {
    case white = "White"
    case albumArt = "Match album art"
    case accent = "Accent color"
}
