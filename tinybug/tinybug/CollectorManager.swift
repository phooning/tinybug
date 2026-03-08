//
//  CollectorManager.swift
//  tinybug
//
//  Created by David on 3/5/26.
//

import Foundation
import CoreLocation
import UIKit
import Combine

class CollectorManager: NSObject, ObservableObject, CLLocationManagerDelegate, URLSessionTaskDelegate {
    static let shared = CollectorManager()
    
    private let locationManager = CLLocationManager()
    
    @Published var targetIPAddress: String = "localhost"
    @Published var lastAPIResponse: String?
    
    private var endpointURL: URL {
        URL(string: "http://\(targetIPAddress):8069/ingest")!
    }
    
    private var backgroundSession: URLSession!
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isMonitoring = false
    @Published var lastTelemetry: String?
    
    override init() {
        super.init()
        
        let config = URLSessionConfiguration.background(withIdentifier: "tinybug.collector.backgroundSession")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        self.backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        self.authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestPermissions() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startMonitoring() {
        guard locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse else { return }
        locationManager.startMonitoringSignificantLocationChanges()
        isMonitoring = true
        
        // Force an immediate API request with the current/latest location
        if let location = locationManager.location {
            sendTelemetry(for: location)
        } else {
            locationManager.requestLocation()
        }
    }
    
    func stopMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
        isMonitoring = false
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if self.authorizationStatus == .authorizedAlways {
                self.startMonitoring()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print("Location updated failed: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        sendTelemetry(for: location)
    }
    
    private func sendTelemetry(for location: CLLocation) {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let device = UIDevice.current
        let payload: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "location": [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "altitude": location.altitude,
                "horizontalAccuracy": location.horizontalAccuracy,
                "verticalAccuracy": location.verticalAccuracy,
                "speed": location.speed,
                "course": location.course
            ],
            "device": [
                "name": device.name,
                "model": device.model,
                "systemName": device.systemName,
                "systemVersion": device.systemVersion,
                "batteryLevel": device.batteryLevel,
                "batteryState": device.batteryState.rawValue
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else { return }
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            DispatchQueue.main.async {
                self.lastTelemetry = jsonString
            }
        }
        
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString + ".json")
        do {
            try jsonData.write(to: fileURL)
            let task = backgroundSession.uploadTask(with: request, fromFile: fileURL)
            task.taskDescription = fileURL.path
            task.resume()
        } catch {
            print("Failed to write temp file: \(error)")
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let response = task.response as? HTTPURLResponse
        let statusCode = response?.statusCode
        let statusString = error != nil ? "Error: \(error!.localizedDescription)" : "Status: \(statusCode?.description ?? "Unknown")"
        
        DispatchQueue.main.async {
            self.lastAPIResponse = statusString
        }
        
        if let path = task.taskDescription {
            let fileURL = URL(fileURLWithPath: path)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
