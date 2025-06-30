//
//  HealthManager.swift
//  Rung Watch App
//
//  Created by chu huy on 30/6/25.
//

import Foundation
import HealthKit
import Combine

class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var workoutQuery: HKAnchoredObjectQuery?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var currentHeartRate: Double = 0
    @Published var currentStressLevel: Double = 0
    @Published var isActive: Bool = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var isConnected: Bool = false
    
    private var baselineHeartRate: Double = 70
    private var recentHeartRates: [Double] = []
    
    init() {
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available")
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.authorizationStatus = .sharingAuthorized
                    self?.isConnected = true
                    self?.startMonitoring()
                    self?.calculateBaseline()
                } else {
                    self?.authorizationStatus = .sharingDenied
                    self?.isConnected = false
                    print("HealthKit authorization denied: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    func startMonitoring() {
        startHeartRateMonitoring()
        startActivityMonitoring()
    }
    
    private func startHeartRateMonitoring() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        healthStore.execute(query)
        heartRateQuery = query
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        
        let recentSamples = samples.filter {
            $0.startDate.timeIntervalSinceNow > -300 // Last 5 minutes
        }
        
        guard let mostRecent = recentSamples.last else { return }
        
        let heartRate = mostRecent.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        
        DispatchQueue.main.async {
            self.currentHeartRate = heartRate
            self.updateRecentHeartRates(heartRate)
            self.calculateStressLevel()
        }
    }
    
    private func startActivityMonitoring() {
        // Monitor for workouts to determine activity state
        let workoutQuery = HKAnchoredObjectQuery(
            type: HKObjectType.workoutType(),
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processWorkoutSamples(samples)
        }
        
        workoutQuery.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processWorkoutSamples(samples)
        }
        
        healthStore.execute(workoutQuery)
        self.workoutQuery = workoutQuery
        
        // Also check recent activity
        checkRecentActivity()
    }
    
    private func processWorkoutSamples(_ samples: [HKSample]?) {
        guard let workouts = samples as? [HKWorkout] else { return }
        
        let now = Date()
        let activeWorkout = workouts.first { workout in
            workout.startDate <= now && (workout.endDate ?? now) >= now
        }
        
        DispatchQueue.main.async {
            self.isActive = activeWorkout != nil
        }
    }
    
    private func checkRecentActivity() {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let now = Date()
        let thirtyMinutesAgo = now.addingTimeInterval(-1800)
        let predicate = HKQuery.predicateForSamples(withStart: thirtyMinutesAgo, end: now, options: .strictEndDate)
        
        let query = HKStatisticsQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] query, statistics, error in
            guard let statistics = statistics,
                  let sum = statistics.sumQuantity() else { return }
            
            let totalEnergy = sum.doubleValue(for: .kilocalorie())
            
            DispatchQueue.main.async {
                // Consider active if burned > 50 calories in last 30 minutes
                self?.isActive = totalEnergy > 50
            }
        }
        
        healthStore.execute(query)
    }
    
    private func calculateBaseline() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let now = Date()
        let oneWeekAgo = now.addingTimeInterval(-604800) // 7 days
        let predicate = HKQuery.predicateForSamples(withStart: oneWeekAgo, end: now, options: .strictEndDate)
        
        let query = HKStatisticsQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { [weak self] query, statistics, error in
            guard let statistics = statistics,
                  let average = statistics.averageQuantity() else { return }
            
            let avgHeartRate = average.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            
            DispatchQueue.main.async {
                self?.baselineHeartRate = avgHeartRate
            }
        }
        
        healthStore.execute(query)
    }
    
    private func updateRecentHeartRates(_ heartRate: Double) {
        recentHeartRates.append(heartRate)
        
        // Keep only last 10 readings
        if recentHeartRates.count > 10 {
            recentHeartRates.removeFirst()
        }
    }
    
    private func calculateStressLevel() {
        guard recentHeartRates.count >= 3 else {
            currentStressLevel = 0.5 // Default neutral state
            return
        }
        
        // Calculate heart rate variability (simplified)
        let variance = calculateVariance(recentHeartRates)
        let currentHR = recentHeartRates.last ?? baselineHeartRate
        
        // Stress indicators:
        // 1. High heart rate relative to baseline
        // 2. Low heart rate variability
        let hrStress = max(0, min(1, (currentHR - baselineHeartRate) / 30))
        let hrvStress = max(0, min(1, (20 - variance) / 20))
        
        // Combine factors
        currentStressLevel = (hrStress * 0.7) + (hrvStress * 0.3)
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(values.count - 1)
    }
    
    func getCurrentHealthState() -> HealthState {
        return HealthState(
            heartRate: currentHeartRate,
            stressLevel: currentStressLevel,
            isActive: isActive,
            timestamp: Date()
        )
    }
    
    deinit {
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
        if let query = workoutQuery {
            healthStore.stop(query)
        }
    }
}
