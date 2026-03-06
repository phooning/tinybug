//
//  tinybugApp.swift
//  tinybug
//
//  Created by David on 3/5/26.
//

import SwiftUI

@main
struct tinybugApp: App {
    @StateObject private var collector = CollectorManager.shared
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(collector)
        }
    }
}
