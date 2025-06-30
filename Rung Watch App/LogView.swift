// MARK: - LogView.swift
import SwiftUI

struct LogView: View {
    @EnvironmentObject private var appData: AppData
    @State private var selectedSegment = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedSegment) {
                Text("Events").tag(0)
                Text("Insights").tag(1)
            }
            .pickerStyle(.wheel)
            .padding(.horizontal)
            .padding(.bottom, 8)

            if selectedSegment == 0 {
                eventsListView
            } else {
                insightsListView
            }
        }
        .navigationTitle("Log")
    }
    
    // MARK: - Events List View
    
    private var eventsListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if appData.hapticEvents.isEmpty {
                    emptyEventsView
                } else {
                    ForEach(appData.hapticEvents) { event in
                        EventRowView(event: event)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var emptyEventsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Events Yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Haptic events will appear here as they occur.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
    
    // MARK: - Insights List View
    
    private var insightsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if appData.aiInsights.isEmpty {
                    emptyInsightsView
                } else {
                    // Summary Stats
                    insightsSummaryView
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Individual Insights
                    ForEach(appData.aiInsights) { insight in
                        InsightRowView(insight: insight)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var emptyInsightsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Insights Yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("AI insights will be generated as you use the app.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
    
    private var insightsSummaryView: some View {
        VStack(spacing: 8) {
            Text("Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                summaryStatView(
                    title: "Total Events",
                    value: "\(appData.hapticEvents.count)",
                    color: .blue
                )
                
                summaryStatView(
                    title: "Response Rate",
                    value: "\(responseRatePercentage)%",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                summaryStatView(
                    title: "Avg Response",
                    value: "\(averageResponseTime)s",
                    color: .orange
                )
                
                summaryStatView(
                    title: "Insights",
                    value: "\(appData.aiInsights.count)",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
    
    private func summaryStatView(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var responseRatePercentage: Int {
        guard !appData.hapticEvents.isEmpty else { return 0 }
        let acknowledgedCount = appData.hapticEvents.filter { $0.acknowledged }.count
        return Int((Double(acknowledgedCount) / Double(appData.hapticEvents.count)) * 100)
    }
    
    private var averageResponseTime: String {
        let responseTimes = appData.hapticEvents.compactMap { $0.responseTime }
        guard !responseTimes.isEmpty else { return "N/A" }
        let average = responseTimes.reduce(0, +) / Double(responseTimes.count)
        return String(format: "%.1f", average)
    }
}

// MARK: - Event Row View

struct EventRowView: View {
    let event: HapticEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Type indicator
            VStack {
                Text(event.type.emoji)
                    .font(.title2)
                
                Circle()
                    .fill(event.acknowledged ? .green : .gray)
                    .frame(width: 8, height: 8)
            }
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.type.rawValue)
                    .font(.footnote)
                    .fontWeight(.medium)
                
                Text(formatTimestamp(event.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("❤️ \(Int(event.heartRate))")
                        .font(.caption2)
                    
                    Text("🧠 \(Int(event.stressLevel * 100))%")
                        .font(.caption2)
                    
                    if let responseTime = event.responseTime {
                        Text("⏱️ \(String(format: "%.1f", responseTime))s")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            // Status indicator
            if event.acknowledged {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        if Calendar.current.isDateInToday(date) {
            return "Today " + formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday " + formatter.string(from: date)
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Insight Row View

struct InsightRowView: View {
    let insight: AIInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Type indicator
                typeIcon
                    .foregroundColor(typeColor)
                
                Text(insight.type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(typeColor)
                
                Spacer()
                
                // Confidence indicator
                confidenceView
            }
            
            Text(insight.message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(formatTimestamp(insight.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
    
    private var typeIcon: Image {
        switch insight.type {
        case .timing:
            return Image(systemName: "clock")
        case .response:
            return Image(systemName: "hand.tap")
        case .stress:
            return Image(systemName: "heart.text.square")
        case .recommendation:
            return Image(systemName: "lightbulb")
        }
    }
    
    private var typeColor: Color {
        switch insight.type {
        case .timing: return .blue
        case .response: return .green
        case .stress: return .orange
        case .recommendation: return .purple
        }
    }
    
    private var confidenceView: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(confidenceColor(for: index))
                    .frame(width: 4, height: 4)
            }
        }
    }
    
    private func confidenceColor(for index: Int) -> Color {
        let threshold = Double(index + 1) / 3.0
        return insight.confidence >= threshold ? .green : .gray.opacity(0.3)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        if Calendar.current.isDateInToday(date) {
            return formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}

#Preview {
    LogView()
        .environmentObject(AppData()) // Provide AppData
        .environmentObject(HealthManager()) // Provide HealthManager (even if not directly used, good practice for consistency)
        .environmentObject(HapticManager()) // Provide HapticManager
        .environmentObject(AIInsightsManager()) // Provide AIInsightsManager
}
