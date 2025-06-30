//
//  DataModels.swift
//  Rung Watch App
//
//  Created by chu huy on 30/6/25.
//

import Foundation
import SwiftUI

struct HealthState {
    let heartRate: Double
    let stressLevel: Double
    let isActive: Bool
    let timestamp: Date
    
    var status: UserStatus {
        if stressLevel > 0.7 || heartRate > 100 {
            return .needToRelax
        } else if stressLevel < 0.3 && heartRate < 80 {
            return .safe
        } else {
            return .calm
        }
    }
}

enum UserStatus: String, CaseIterable {
    case safe = "Safe"
    case needToRelax = "Need to Relax"
    case calm = "Calm"
    
    var color: Color {
        switch self {
        case .safe: return .green
        case .needToRelax: return .orange
        case .calm: return .blue
        }
    }
    
    var emoji: String {
        switch self {
        case .safe: return "✅"
        case .needToRelax: return "⚠️"
        case .calm: return "😌"
        }
    }
}

struct HapticEvent: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: HapticType
    let acknowledged: Bool
    let responseTime: TimeInterval?
    let heartRate: Double
    let stressLevel: Double
}

enum HapticType: String, CaseIterable, Codable {
    case safe = "Safe Vibration"
    case stress = "Relax Reminder"
    case mindfulness = "Mindfulness Reminder"
    
    var emoji: String {
        switch self {
        case .safe: return "💚"
        case .stress: return "🧘‍♀️"
        case .mindfulness: return "🔔"
        }
    }
}

enum SensitivityMode: String, CaseIterable {
    case light = "Light"
    case medium = "Medium"
    case deep = "Deep"
    
    var threshold: Double {
        switch self {
        case .light: return 0.8
        case .medium: return 0.6
        case .deep: return 0.4
        }
    }
}

struct AIInsight: Identifiable, Codable {
    let id = UUID()
    let message: String
    let confidence: Double
    let timestamp: Date
    let type: InsightType
}

enum InsightType: String, Codable, CaseIterable {
    case timing = "Timing"
    case response = "Response Pattern"
    case stress = "Stress Pattern"
    case recommendation = "Recommendation"
}

class AppData: ObservableObject {
    @Published var currentHealthState: HealthState?
    @Published var hapticEvents: [HapticEvent] = []
    @Published var sensitivityMode: SensitivityMode = .medium
    @Published var isMonitoringEnabled = true
    @Published var aiInsights: [AIInsight] = []
    @Published var reminderInterval: TimeInterval = Constants.defaultReminderInterval
    @Published var lastAcknowledgedTime: Date?
    
    init() {
        loadData()
    }
    
    func addHapticEvent(_ event: HapticEvent) {
        hapticEvents.insert(event, at: 0) // Most recent first
        
        // Keep only recent events to manage storage
        if hapticEvents.count > Constants.maxStoredEvents {
            hapticEvents = Array(hapticEvents.prefix(Constants.maxStoredEvents))
        }
        
        saveData()
    }
    
    func updateHapticEvent(_ eventId: UUID, acknowledged: Bool, responseTime: TimeInterval?) {
        if let index = hapticEvents.firstIndex(where: { $0.id == eventId }) {
            let event = hapticEvents[index]
            let updatedEvent = HapticEvent(
                timestamp: event.timestamp,
                type: event.type,
                acknowledged: acknowledged,
                responseTime: responseTime,
                heartRate: event.heartRate,
                stressLevel: event.stressLevel
            )
            hapticEvents[index] = updatedEvent
            
            if acknowledged {
                lastAcknowledgedTime = Date()
            }
            
            saveData()
        }
    }
    
    func updateHealthState(_ state: HealthState) {
        currentHealthState = state
    }
    
    func addInsight(_ insight: AIInsight) {
        aiInsights.insert(insight, at: 0)
        
        // Keep only recent insights
        if aiInsights.count > 10 {
            aiInsights = Array(aiInsights.prefix(10))
        }
        
        saveData()
    }
    
    // Simple local storage
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(hapticEvents) {
            UserDefaults.standard.set(encoded, forKey: "hapticEvents")
        }
        
        if let encoded = try? JSONEncoder().encode(aiInsights) {
            UserDefaults.standard.set(encoded, forKey: "aiInsights")
        }
        
        UserDefaults.standard.set(sensitivityMode.rawValue, forKey: "sensitivityMode")
        UserDefaults.standard.set(isMonitoringEnabled, forKey: "isMonitoringEnabled")
        UserDefaults.standard.set(reminderInterval, forKey: "reminderInterval")
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "hapticEvents"),
           let events = try? JSONDecoder().decode([HapticEvent].self, from: data) {
            hapticEvents = events
        }
        
        if let data = UserDefaults.standard.data(forKey: "aiInsights"),
           let insights = try? JSONDecoder().decode([AIInsight].self, from: data) {
            aiInsights = insights
        }
        
        if let modeString = UserDefaults.standard.object(forKey: "sensitivityMode") as? String,
           let mode = SensitivityMode(rawValue: modeString) {
            sensitivityMode = mode
        }
        
        isMonitoringEnabled = UserDefaults.standard.object(forKey: "isMonitoringEnabled") as? Bool ?? true
        reminderInterval = UserDefaults.standard.object(forKey: "reminderInterval") as? TimeInterval ?? Constants.defaultReminderInterval
    }
}

