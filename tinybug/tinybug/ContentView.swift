//
//  ContentView.swift
//  tinybug
//
//  Created by David on 3/5/26.
//

import SwiftUI
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var collector: CollectorManager
    
    var body: some View {
        VStack {
            Text("tinybug").font(.largeTitle).bold()
            Text("Collection Status").font(.headline)
            ScrollView(.vertical, showsIndicators: false) {
                HStack {
                    Text("Background Tracking:")
                    Spacer()
                    Text("Inactive").foregroundColor(.red).bold()
                }.padding(.horizontal)
                
                HStack {
                    Text("Authorization:")
                    Spacer()
                    Text(statusText(for: collector.authorizationStatus)).bold()
                }.padding(.horizontal)
                Spacer()
                if collector.authorizationStatus == .notDetermined || collector.authorizationStatus == .denied || collector.authorizationStatus == .restricted {
                    Button(action: {
                        collector.requestPermissions()
                    }) {
                        Text("Request Permissions")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }.padding(.horizontal)
                    
                    if collector.authorizationStatus == .denied {
                        Text("Please enable location permissions in Settings to use this app.").font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if !collector.isMonitoring {
                    Button(action: {
                        collector.startMonitoring()
                    }) {
                        Text("Start Monitoring").foregroundColor(Color.white).padding().frame(maxWidth: .infinity).background(Color.green).cornerRadius(20)
                    }.padding(.horizontal)
                } else {
                    Button(action: {
                        collector.stopMonitoring()
                    }) {
                        Text("Stop Monitoring")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(20)
                    }
                    .padding(.horizontal)
                }
                Spacer()
            }
        }
        .padding()
    }
    
    private func statusText(for status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When In Use"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    ContentView().environmentObject(CollectorManager())
}
