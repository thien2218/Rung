//
//  Constants.swift
//  Rung Watch App
//
//  Created by chu huy on 30/6/25.
//

import Foundation

struct Constants {
    static let positiveMessages = [
        "Take a deep breath 🌸",
        "You're doing great! 💪",
        "Stay present, stay calm 🧘‍♀️",
        "This moment is yours ✨",
        "Breathe in peace, breathe out stress 🌊",
        "You've got this! 🌟",
        "Find your center 🎯",
        "Be kind to yourself today 💕"
    ]
    
    static let defaultReminderInterval: TimeInterval = 3600 // 1 hour
    static let maxDailyReminders = 8
    static let minResponseTime: TimeInterval = 1.0
    static let maxStoredEvents = 50 // Limit for watch storage
}
