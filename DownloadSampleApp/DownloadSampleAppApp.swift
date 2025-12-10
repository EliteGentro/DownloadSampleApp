//
//  DownloadSampleAppApp.swift
//  DownloadSampleApp
//
//  Created by Humberto Genaro Cisneros Salinas on 08/12/25.
//

import SwiftUI
import SwiftData

@main
struct DownloadSampleAppApp: App {
    let sharedModelContainer: ModelContainer
    let downloadManager: DownloadManager

    init() {
        let schema = Schema([
            Content.self,
        ])
        
        let configuration = ModelConfiguration(
            "MainStore",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.sharedModelContainer = container
            self.downloadManager = DownloadManager(modelContainer: container)
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .environmentObject(downloadManager)
        }
    }
}
