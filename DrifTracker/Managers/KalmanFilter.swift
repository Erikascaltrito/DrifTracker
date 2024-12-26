//
//  KalmanFilter.swift
//  KalmanFilter
//
//  Created by Oleksii on 18/08/16.
//  Copyright © 2016 Oleksii Dykan. All rights reserved.
//

import Foundation

/// Simple Kalman Filter for one-dimensional data
class SimpleKalmanFilter {
    private var stateEstimate: Double  // State estimate
    private var estimateUncertainty: Double  // Estimate uncertainty
    private let measurementNoise: Double  // Measurement noise (from GPS)
    private let processNoise: Double  // Process noise (from gyroscope)

    init(initialEstimate: Double, initialUncertainty: Double, measurementNoise: Double, processNoise: Double) {
        self.stateEstimate = initialEstimate
        self.estimateUncertainty = initialUncertainty
        self.measurementNoise = measurementNoise
        self.processNoise = processNoise
    }

    /// Predict step: Update the state estimate using the process model
    func predict(rate: Double, dt: Double) {
        stateEstimate += rate * dt  // Update the state estimate using the rate of change
        estimateUncertainty += processNoise  // Increase the uncertainty
    }

    /// Update step: Correct the state estimate using the measurement
    func update(measurement: Double) {
        let kalmanGain = estimateUncertainty / (estimateUncertainty + measurementNoise)
        stateEstimate += kalmanGain * (measurement - stateEstimate)  // Update the state estimate
        estimateUncertainty *= (1 - kalmanGain)  // Update the uncertainty
    }

    /// Get the current state estimate
    func getState() -> Double {
        return stateEstimate
    }
}
