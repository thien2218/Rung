//
//  HapticManager.swift
//  Rung Watch App
//
//  Created by chu huy on 30/6/25.
//

import Foundation
import WatchKit

class HapticManager: ObservableObject {
    func triggerHaptic(for type: HapticType, sensitivity: SensitivityMode) {
        let device = WKInterfaceDevice.current()
        
        switch type {
        case .safe:
            // Light, brief vibration for positive state
            device.play(.click)
            
        case .stress:
            // More prominent vibration for stress relief reminder
            switch sensitivity {
            case .light:
                device.play(.notification)
            case .medium:
                device.play(.directionUp)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    device.play(.directionDown)
                }
            case .deep:
                device.play(.directionUp)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    device.play(.directionDown)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    device.play(.click)
                }
            }
            
        case .mindfulness:
            // Gentle, mindful vibration pattern
            device.play(.start)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                device.play(.click)
            }
        }
    }
    
    func getRandomPositiveMessage() -> String {
        return Constants.positiveMessages.randomElement() ?? "Stay mindful! 🌟"
    }
}
