//
//  AIInsightsManager.swift
//  Rung Watch App
//
//  Created by chu huy on 30/6/25.
//

import Foundation
import Combine

class AIInsightsManager: ObservableObject {
    @Published var insights: [AIInsight] = []
    
    private var lastAnalysisTime = Date.distantPast
    private let analysisInterval: TimeInterval = 3600 // 1 hour
    
    func analyzeUserBehavior(hapticEvents: [HapticEvent], appData: AppData) {
        // Throttle analysis to avoid excessive processing
        let now = Date()
        guard now.timeIntervalSince(lastAnalysisTime) > analysisInterval else { return }
        lastAnalysisTime = now
        
        generateTimeBasedInsights(from: hapticEvents, appData: appData)
        generateResponsePatternInsights(from: hapticEvents, appData: appData)
        generateStressPatternInsights(from: hapticEvents, appData: appData)
        generateAdaptiveRecommendations(from: hapticEvents, appData: appData)
    }
    
    private func generateTimeBasedInsights(from events: [HapticEvent], appData: AppData) {
        let acknowledgedEvents = events.filter { $0.acknowledged }
        guard acknowledgedEvents.count > 5 else { return }
        
        let hourCounts = Dictionary(grouping: acknowledgedEvents) { event in
            Calendar.current.component(.hour, from: event.timestamp)
        }.mapValues { $0.count }
        
        if let bestHour = hourCounts.max(by: { $0.value < $1.value }) {
            let insight = AIInsight(
                message: "You respond best to reminders around \(formatHour(bestHour.key)). Consider scheduling more reminders during this time.",
                confidence: min(0.9, Double(bestHour.value) / Double(acknowledgedEvents.count) + 0.3),
                timestamp: Date(),
                type: .timing
            )
            appData.addInsight(insight)
        }
    }
    
    private func generateResponsePatternInsights(from events: [HapticEvent], appData: AppData) {
        let recentEvents = Array(events.prefix(20))
        guard recentEvents.count >= 10 else { return }
        
        let acknowledgedCount = recentEvents.filter { $0.acknowledged }.count
        let responseRate = Double(acknowledgedCount) / Double(recentEvents.count)
        
        let avgResponseTime = recentEvents
            .compactMap { $0.responseTime }
            .reduce(0, +) / Double(recentEvents.compactMap { $0.responseTime }.count)
        
        if responseRate < 0.3 {
            let insight = AIInsight(
                message: "Low response rate (\(Int(responseRate * 100))%). Try reducing frequency or adjusting sensitivity to Light mode.",
                confidence: 0.8,
                timestamp: Date(),
                type: .response
            )
            appData.addInsight(insight)
        } else if responseRate > 0.8 && avgResponseTime < 5.0 {
            let insight = AIInsight(
                message: "Great engagement! (\(Int(responseRate * 100))% response rate). You might benefit from more frequent reminders.",
                confidence: 0.9,
                timestamp: Date(),
                type: .response
            )
            appData.addInsight(insight)
        }
    }
    
    private func generateStressPatternInsights(from events: [HapticEvent], appData: AppData) {
        let stressEvents = events.filter { $0.type == .stress }
        guard stressEvents.count > 5 else { return }
        
        // Analyze stress patterns by day of week
        let weekdayStress = stressEvents.filter {
            let weekday = Calendar.current.component(.weekday, from: $0.timestamp)
            return weekday >= 2 && weekday <= 6 // Monday to Friday
        }
        
        let weekendStress = stressEvents.filter {
            let weekday = Calendar.current.component(.weekday, from: $0.timestamp)
            return weekday == 1 || weekday == 7 // Sunday or Saturday
        }
        
        if Double(weekdayStress.count) / Double(stressEvents.count) > 0.7 {
            let insight = AIInsight(
                message: "Most stress occurs on weekdays. Consider adding more morning mindfulness sessions before work.",
                confidence: 0.75,
                timestamp: Date(),
                type: .stress
            )
            appData.addInsight(insight)
        }
        
        // Analyze stress vs heart rate correlation
        let highHRStress = stressEvents.filter { $0.heartRate > 90 }
        if Double(highHRStress.count) / Double(stressEvents.count) > 0.6 {
            let insight = AIInsight(
                message: "Stress often correlates with elevated heart rate. Deep breathing exercises may help.",
                confidence: 0.8,
                timestamp: Date(),
                type: .stress
            )
            appData.addInsight(insight)
        }
    }
    
    private func generateAdaptiveRecommendations(from events: [HapticEvent], appData: AppData) {
        let recentEvents = Array(events.prefix(30))
        guard recentEvents.count >= 10 else { return }
        
        let acknowledgedEvents = recentEvents.filter { $0.acknowledged }
        let responseTimes = acknowledgedEvents.compactMap { $0.responseTime }
        
        if responseTimes.count >= 5 {
            let avgResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
            
            if avgResponseTime > 10.0 {
                let insight = AIInsight(
                    message: "Slow response times suggest you might benefit from gentler, less frequent reminders.",
                    confidence: 0.7,
                    timestamp: Date(),
                    type: .recommendation
                )
                appData.addInsight(insight)
            } else if avgResponseTime < 2.0 {
                let insight = AIInsight(
                    message: "Quick responses! You might handle more frequent mindfulness reminders well.",
                    confidence: 0.8,
                    timestamp: Date(),
                    type: .recommendation
                )
                appData.addInsight(insight)
            }
        }
    }
    
    func getOptimalReminderTimes(from events: [HapticEvent]) -> [Int] {
        let acknowledgedEvents = events.filter { $0.acknowledged }
        let hourCounts = Dictionary(grouping: acknowledgedEvents) { event in
            Calendar.current.component(.hour, from: event.timestamp)
        }.mapValues { $0.count }
        
        return hourCounts.sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}
