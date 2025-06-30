//
//  ContentView.swift
//  Rung Watch App
//
//  Created by chu huy on 30/6/25.
//

// MARK: - ContentView.swift

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var appData: AppData
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var hapticManager: HapticManager
    @EnvironmentObject private var aiManager: AIInsightsManager
    
    @State private var currentTab = 0
    @State private var showingAcknowledgment = false
    @State private var currentHapticEventId: UUID?
    @State private var hapticTriggerTime: Date?
    @State private var monitoringTimer: Timer?
    @State private var reminderTimer: Timer?
    
    var body: some View {
        TabView(selection: $currentTab) {
            // Main Status View
            mainStatusView
                .tag(0)
            
            // Log View
            LogView()
                .tag(1)
            
            // Settings View
            SettingsView()
                .tag(2)
        }
        .tabViewStyle(PageTabViewStyle())
        .onAppear {
            startMonitoring()
            setupReminderTimer()
        }
        .onDisappear {
            stopMonitoring()
        }
        .sheet(isPresented: $showingAcknowledgment) {
            acknowledgmentView
        }
    }
    
    private var mainStatusView: some View {
        VStack(spacing: 12) {
            // Health Status Indicator
            statusIndicator
            
            // Current Metrics
            metricsView
            
            // Connection Status
            connectionStatusView
        }
        .padding()
        .navigationTitle("Mindful")
    }
    
    private var statusIndicator: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(currentStatus.color.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Text(currentStatus.emoji)
                    .font(.title)
            }
            
            Text(currentStatus.rawValue)
                .font(.headline)
                .foregroundColor(currentStatus.color)
            
            if let message = currentMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }
    
    private var metricsView: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(Int(healthManager.currentHeartRate)) BPM")
                    .font(.caption)
            }
            
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.orange)
                Text("Stress: \(Int(healthManager.currentStressLevel * 100))%")
                    .font(.caption)
            }
            
            if healthManager.isActive {
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundColor(.green)
                    Text("Active")
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
    
    private var connectionStatusView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(healthManager.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            
            Text(healthManager.isConnected ? "Connected" : "Disconnected")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var acknowledgmentView: some View {
        VStack(spacing: 16) {
            Text(hapticManager.getRandomPositiveMessage())
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Acknowledge") {
                acknowledgeHaptic()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private var currentStatus: UserStatus {
        guard let healthState = appData.currentHealthState else {
            return .calm
        }
        return healthState.status
    }
    
    private var currentMessage: String? {
        guard let insight = appData.aiInsights.first else { return nil }
        return insight.message
    }
    
    // MARK: - Monitoring Logic
    
    private func startMonitoring() {
        guard appData.isMonitoringEnabled else { return }
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            updateHealthState()
            checkForHapticTrigger()
            
            // Periodic AI analysis
            if appData.hapticEvents.count > 0 {
                aiManager.analyzeUserBehavior(hapticEvents: appData.hapticEvents, appData: appData)
            }
        }
    }
    
    private func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        reminderTimer?.invalidate()
        reminderTimer = nil
    }
    
    private func setupReminderTimer() {
        reminderTimer = Timer.scheduledTimer(withTimeInterval: appData.reminderInterval, repeats: true) { _ in
            triggerMindfulnessReminder()
        }
    }
    
    private func updateHealthState() {
        let healthState = healthManager.getCurrentHealthState()
        appData.updateHealthState(healthState)
    }
    
    private func checkForHapticTrigger() {
        guard let healthState = appData.currentHealthState else { return }
        
        let shouldTrigger = shouldTriggerHaptic(for: healthState)
        
        if shouldTrigger.trigger {
            triggerHaptic(type: shouldTrigger.type, healthState: healthState)
        }
    }
    
    private func shouldTriggerHaptic(for healthState: HealthState) -> (trigger: Bool, type: HapticType) {
        // Avoid spam - check last trigger time
        if let lastEvent = appData.hapticEvents.first,
           Date().timeIntervalSince(lastEvent.timestamp) < 300 { // 5 minutes
            return (false, .safe)
        }
        
        // Don't trigger during active periods
        if healthState.isActive {
            return (false, .safe)
        }
        
        // Check stress level threshold based on sensitivity
        let threshold = appData.sensitivityMode.threshold
        
        if healthState.stressLevel > threshold {
            return (true, .stress)
        } else if healthState.status == .safe && healthState.stressLevel < 0.3 {
            // Occasional positive reinforcement
            if Int.random(in: 1...10) == 1 { // 10% chance
                return (true, .safe)
            }
        }
        
        return (false, .safe)
    }
    
    private func triggerHaptic(type: HapticType, healthState: HealthState) {
        let event = HapticEvent(
            timestamp: Date(),
            type: type,
            acknowledged: false,
            responseTime: nil,
            heartRate: healthState.heartRate,
            stressLevel: healthState.stressLevel
        )
        
        appData.addHapticEvent(event)
        hapticManager.triggerHaptic(for: type, sensitivity: appData.sensitivityMode)
        
        // Show acknowledgment sheet for stress reminders
        if type == .stress {
            currentHapticEventId = event.id
            hapticTriggerTime = Date()
            showingAcknowledgment = true
        }
        
        // Generate new insights after haptic events
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            aiManager.analyzeUserBehavior(hapticEvents: appData.hapticEvents, appData: appData)
        }
    }
    
    private func triggerMindfulnessReminder() {
        guard appData.isMonitoringEnabled else { return }
        
        // Check if it's a good time based on AI insights
        let currentHour = Calendar.current.component(.hour, from: Date())
        let optimalTimes = aiManager.getOptimalReminderTimes(from: appData.hapticEvents)
        
        // If we have optimal times and current time isn't optimal, skip
        if !optimalTimes.isEmpty && !optimalTimes.contains(currentHour) {
            // Only trigger if user hasn't been active recently
            guard let lastAcknowledged = appData.lastAcknowledgedTime,
                  Date().timeIntervalSince(lastAcknowledged) > 1800 else { return } // 30 minutes
        }
        
        let healthState = healthManager.getCurrentHealthState()
        triggerHaptic(type: .mindfulness, healthState: healthState)
    }
    
    private func acknowledgeHaptic() {
        guard let eventId = currentHapticEventId,
              let triggerTime = hapticTriggerTime else { return }
        
        let responseTime = Date().timeIntervalSince(triggerTime)
        appData.updateHapticEvent(eventId, acknowledged: true, responseTime: responseTime)
        
        showingAcknowledgment = false
        currentHapticEventId = nil
        hapticTriggerTime = nil
        
        // Generate insights after acknowledgment
        aiManager.analyzeUserBehavior(hapticEvents: appData.hapticEvents, appData: appData)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppData()) // Provide AppData
        .environmentObject(HealthManager()) // Provide HealthManager
        .environmentObject(HapticManager()) // Provide HapticManager
        .environmentObject(AIInsightsManager()) // Provide AIInsightsManager
}
