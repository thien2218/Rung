//
//  RungApp.swift
//  Rung Watch App
//
//  Created by chu huy on 30/6/25.
//

import SwiftUI

@main
struct Rung_Watch_AppApp: App {
    @StateObject private var appData = AppData()
    @StateObject private var healthManager = HealthManager()
    @StateObject private var hapticManager = HapticManager()
    @StateObject private var aiManager = AIInsightsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
                .environmentObject(healthManager)
                .environmentObject(hapticManager)
                .environmentObject(aiManager)
        }
    }
}
