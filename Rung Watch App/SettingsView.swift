//
//  SettingsView.swift
//  Rung Watch App
//
//  Created by chu huy on 30/6/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appData: AppData
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var hapticManager: HapticManager
    @EnvironmentObject private var aiManager: AIInsightsManager
    
    @State private var showingHealthPermissions = false
    @State private var showingDataReset = false
    @State private var showingAbout = false
    
    var body: some View {
        // Removed NavigationView wrapper if SettingsView is directly a tab content
        // If nested navigation is desired within settings, keep it.
        List {
            monitoringSection
            sensitivitySection
            reminderSection
            healthSection
            dataSection
        }
        .navigationTitle("Settings")
        // Removed .navigationBarTitleDisplayMode(.inline) as it's often default/redundant on watchOS
        .sheet(isPresented: $showingHealthPermissions) {
            healthPermissionsView // This view itself might benefit from simplification (see below)
        }
        .alert("Reset All Data", isPresented: $showingDataReset) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will permanently delete all haptic events, AI insights, and reset settings to defaults. This action cannot be undone.")
        }
    }

    
    // MARK: - Monitoring Section
    
    private var monitoringSection: some View {
        Section {
            Toggle("Enable Monitoring", isOn: $appData.isMonitoringEnabled)
                .toggleStyle(SwitchToggleStyle())
            
            if appData.isMonitoringEnabled {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .frame(width: 16)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Heart Rate")
                            .font(.caption)
                        Text("\(Int(healthManager.currentHeartRate)) BPM")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(healthManager.isConnected ? .green : .red)
                        .frame(width: 6, height: 6)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Monitoring")
        } footer: {
            if !appData.isMonitoringEnabled {
                Text("Enable monitoring to receive mindfulness reminders and stress notifications.")
            }
        }
    }
    
    // MARK: - Sensitivity Section
    
    private var sensitivitySection: some View {
        Section {
            ForEach(SensitivityMode.allCases, id: \.self) { mode in
                Button(action: {
                    appData.sensitivityMode = mode
                    hapticManager.triggerHaptic(for: .safe, sensitivity: mode)
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.rawValue)
                                .foregroundColor(.primary)
                                .font(.system(size: 14, weight: .medium))
                            
                            Text(mode.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        if appData.sensitivityMode == mode {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        } header: {
            Text("Sensitivity")
        } footer: {
            Text("Tap to test haptic feedback. Higher sensitivity triggers reminders more frequently.")
        }
    }
    
    // MARK: - Reminder Section
    
    private var reminderSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Reminder Interval")
                        .font(.system(size: 14))
                    Spacer()
                    Text(formatReminderInterval(appData.reminderInterval))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { appData.reminderInterval },
                        set: { appData.reminderInterval = $0 }
                    ),
                    in: 300...3600, // 5 minutes to 1 hour
                    step: 300
                )
                .accentColor(.blue)
            }
            .padding(.vertical, 4)
            
            if !appData.hapticEvents.isEmpty {
                let optimalTimes = aiManager.getOptimalReminderTimes(from: appData.hapticEvents)
                if !optimalTimes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Suggested Times")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatOptimalTimes(optimalTimes))
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("AI learns your response patterns to suggest optimal reminder times.")
        }
    }
    
    // MARK: - Health Section
    
    private var healthSection: some View {
        Section {
            Button(action: {
                showingHealthPermissions = true
            }) {
                HStack {
                    Image(systemName: "heart.text.square")
                        .foregroundColor(.red)
                        .frame(width: 16)
                    
                    Text("Health Permissions")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(healthManager.authorizationStatus == .sharingAuthorized ? "Granted" : "Required")
                        .font(.caption2)
                        .foregroundColor(healthManager.authorizationStatus == .sharingAuthorized ? .green : .orange)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.orange)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stress Level")
                        .font(.caption)
                    Text("\(Int(healthManager.currentStressLevel * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if healthManager.isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.run")
                            .foregroundColor(.green)
                            .font(.caption2)
                        Text("Active")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
        } header: {
            Text("Health Data")
        }
    }
    
    // MARK: - Data Section
    
    private var dataSection: some View {
        Section {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.blue)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Events")
                        .font(.caption)
                    Text("\(appData.hapticEvents.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Response Rate")
                        .font(.caption)
                    Text(formatResponseRate())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.purple)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Insights")
                        .font(.caption)
                    Text("\(appData.aiInsights.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let lastInsight = appData.aiInsights.first {
                    Text("Last: \(lastInsight.type.rawValue)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {
                showingDataReset = true
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .frame(width: 16)
                    
                    Text("Reset All Data")
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(PlainButtonStyle())
        } header: {
            Text("Data Management")
        }
    }
    
    // MARK: - Health Permissions View
    
    private var healthPermissionsView: some View {
        // Removed NavigationView here to simplify modal presentation
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)

            Text("Health Access")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Mindful needs access to your health data to provide personalized mindfulness reminders.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                HealthPermissionRow(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    description: "Monitor stress patterns",
                    color: .red
                )
                HealthPermissionRow(
                    icon: "bolt.fill",
                    title: "Active Energy",
                    description: "Detect activity levels",
                    color: .orange
                )
                HealthPermissionRow(
                    icon: "figure.walk",
                    title: "Workouts",
                    description: "Understand activity patterns",
                    color: .green
                )
            }
            .padding()

            Spacer()

            VStack(spacing: 8) {
                Text("Current Status: \(healthManager.authorizationStatus == .sharingAuthorized ? "Authorized" : "Not Authorized")")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Button(healthManager.authorizationStatus == .sharingAuthorized ? "Reauthorize" : "Request Permissions") {
                    // Note: HealthManager doesn't expose requestAuthorization publicly
                    // In a real implementation, you'd need to add this method
                    showingHealthPermissions = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            // Add a dismiss button directly on the modal content for clarity
            Button("Done") {
                showingHealthPermissions = false
            }
            .buttonStyle(.bordered)
        }
        .padding()
        // No navigationTitle or toolbar modifiers here, as it's a simple modal
    }
    
    // MARK: - Helper Functions
    
    private func formatReminderInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            return "\(hours)h"
        }
    }
    
    private func formatOptimalTimes(_ times: [Int]) -> String {
        return times.map { hour in
            let formatter = DateFormatter()
            formatter.dateFormat = "ha"
            let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
            return formatter.string(from: date).lowercased()
        }.joined(separator: ", ")
    }
    
    private func formatResponseRate() -> String {
        guard !appData.hapticEvents.isEmpty else { return "0%" }
        
        let acknowledgedCount = appData.hapticEvents.filter { $0.acknowledged }.count
        let rate = Double(acknowledgedCount) / Double(appData.hapticEvents.count) * 100
        return "\(Int(rate))%"
    }
    
    private func resetAllData() {
        appData.hapticEvents.removeAll()
        appData.aiInsights.removeAll()
        appData.sensitivityMode = .medium
        appData.reminderInterval = Constants.defaultReminderInterval
        appData.lastAcknowledgedTime = nil
        appData.isMonitoringEnabled = true
    }
}

// MARK: - Health Permission Row

struct HealthPermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - SensitivityMode Extension

extension SensitivityMode {
    var description: String {
        switch self {
        case .light:
            return "Less frequent reminders"
        case .medium:
            return "Balanced monitoring"
        case .deep:
            return "More sensitive to stress"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppData())
        .environmentObject(HealthManager())
        .environmentObject(HapticManager())
        .environmentObject(AIInsightsManager())
}
