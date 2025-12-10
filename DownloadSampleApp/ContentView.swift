//
//  ContentView.swift
//  DownloadSampleApp
//
//  Created by Humberto Genaro Cisneros Salinas on 08/12/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NavigationStack{
            ManageContentsView()
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Content.self)
    let mockManager = DownloadManager(modelContainer: container)
    
    ContentView()
        .modelContainer(container)
        .environmentObject(mockManager)
}
