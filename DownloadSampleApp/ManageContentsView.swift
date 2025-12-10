//
//  DownloadContentsView.swift
//  Coffey
//
//  Created by Humberto Genaro Cisneros Salinas on 17/10/25.
//

import SwiftUI
import SwiftData

struct ManageContentsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var downloadManager: DownloadManager
    
    @State private var searchText = ""
    @State private var filterType: String = "all"
    
    var contents: [Content] = Content.mockContents
    
    var filteredContents: [Content] {
        var result = contents
        
        // Apply type filter
        if filterType != "all" {
            if filterType == "downloaded" {
                result = result.filter { downloadManager.isDownloaded($0) }
            } else {
                result = result.filter { $0.resourceType == filterType }
            }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.details.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search Content...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 10)
            
            // Filter buttons
            HStack(spacing: 12) {
                FilterButton(title: "All", isSelected: filterType == "all") {
                    filterType = "all"
                }
                FilterButton(title: "Videos", isSelected: filterType == "video") {
                    filterType = "video"
                }
                FilterButton(title: "PDFs", isSelected: filterType == "pdf") {
                    filterType = "pdf"
                }
                FilterButton(title: "Downloaded", isSelected: filterType == "downloaded") {
                    filterType = "downloaded"
                }
            }
            .padding()
            
            ScrollView {
                VStack {
                    
                    // Grid of learning content
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                        ForEach(filteredContents) { content in
                            // Navigate to detailed content view on tap
                            NavigationLink(destination: ContentDetailView(content: content)) {
                                ZStack(alignment: .topTrailing) {
                                    MenuCellView(
                                        systemName: content.resourceType == "video" ? "video.fill" : "book.fill",
                                        title: content.name
                                    )
                                    
                                    // Offline badge
                                    if downloadManager.isDownloaded(content) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title2)
                                            .padding(8)
                                            .background(Color.white.opacity(0.9))
                                            .clipShape(Circle())
                                            .padding(8)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Learning Content")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Check download status when view appears
            for content in contents {
                downloadManager.checkFileExists(content: content)
            }
        }
    }
}

// Filter button component
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}


#Preview {
    let container = try! ModelContainer(for: Content.self)
    let mockManager = DownloadManager(modelContainer: container)
    
    ManageContentsView()
        .modelContainer(container)
        .environmentObject(mockManager)
}
