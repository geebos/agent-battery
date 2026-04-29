//
//  agent_batteryApp.swift
//  agent-battery
//
//  Created by 童玉龙 on 2026/4/29.
//

import SwiftUI
import CoreData

@main
struct agent_batteryApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
