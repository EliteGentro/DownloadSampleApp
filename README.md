# DownloadSampleApp

A SwiftUI-based iOS application demonstrating offline content management with **SwiftData** persistence and a robust **DownloadManager** system. This app showcases how to download, store, and manage multimedia content (videos and PDFs) with progress tracking, error handling, and search/filter capabilities.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [DownloadManager Deep Dive](#downloadmanager-deep-dive)
- [SwiftData Integration](#swiftdata-integration)
- [Current Implementation Status](#current-implementation-status)
- [Project Structure](#project-structure)
- [Usage](#usage)
- [Future Enhancements](#future-enhancements)

## Overview

DownloadSampleApp is designed to demonstrate a production-ready pattern for managing downloadable content in iOS apps. It combines SwiftData's modern persistence framework with a custom `DownloadManager` class that handles all download operations, file management, and state synchronization.

The app is **built for SwiftData** but currently uses **mock data** (`Content.mockContents`) for demonstration purposes, making it easy to test without requiring a backend API or database setup.

## Features

### Core Functionality
- **Download Management**: Download videos (MP4) and PDFs from remote URLs
- **Offline Access**: Access downloaded content without internet connection
- **Progress Tracking**: Real-time download progress with percentage display
- **Error Handling**: User-friendly error alerts for network issues and download failures
- **File Management**: Delete downloaded files to free up storage
- **Network Detection**: Automatic network connectivity check before downloads

### User Interface
- **Grid View**: Browse content in a responsive grid layout
- **Search**: Full-text search across content names and descriptions
- **Filters**: Filter by content type (Videos, PDFs) or downloaded status
- **Offline Indicators**: Visual badges showing which content is available offline
- **Video Player**: Built-in full-screen video player with native controls
- **PDF Viewer**: Native PDF viewing with zoom and scroll support

## Architecture

### Core Components

```
DownloadSampleApp
├── App Layer
│   └── DownloadSampleAppApp.swift      # App entry point, SwiftData setup
├── Models
│   └── Content.swift                    # SwiftData model with Codable support
├── Managers
│   └── DownloadManager.swift           # Central download orchestration
├── Views
│   ├── ContentView.swift               # Root navigation container
│   ├── ManageContentsView.swift        # Main grid view with search/filter
│   ├── ContentDetailView.swift         # Detail view with download controls
│   ├── VideoView.swift                 # Full-screen video player
│   ├── PDFViewer.swift                 # Full-screen PDF viewer
│   ├── PDFKitView.swift                # PDFKit wrapper
│   └── MenuCellView.swift              # Reusable grid cell component
```

### Content Playback Views

The app includes specialized views for playing downloaded content, leveraging native iOS frameworks for optimal performance.

#### VideoView

The `VideoView` provides a full-screen video playback experience using AVKit's `VideoPlayer`:

```swift
struct VideoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var downloadManager: DownloadManager
    @State var player = AVPlayer()
    let content: Content
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VideoPlayer(player: player)
                .ignoresSafeArea()
            
            // Close button overlay
            Button(action: {
                player.pause()
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
            }
        }
        .onAppear {
            if let playerItem = downloadManager.getVideoFileAsset(content: content) {
                player = AVPlayer(playerItem: playerItem)
                player.play()
            }
        }
        .onDisappear {
            player.pause()
        }
    }
}
```

**Key Features**:
- **Full-screen playback**: Uses `ignoresSafeArea()` for immersive viewing
- **Native controls**: AVKit's `VideoPlayer` provides standard iOS video controls (play, pause, scrubbing, AirPlay)
- **Local file playback**: Retrieves `AVPlayerItem` from `DownloadManager` for offline viewing
- **Lifecycle management**: Automatically pauses video when view disappears
- **Custom close button**: Overlaid on top-right for easy dismissal

#### PDFViewerContainer

The `PDFViewerContainer` provides a wrapper view for PDF display with dismissal controls:

```swift
struct PDFViewerContainer: View {
    @Environment(\.dismiss) private var dismiss
    let content: Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PDFKitView(content: content)
                .ignoresSafeArea()

            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
            }
        }
    }
}
```

**Responsibilities**:
- **Container view**: Wraps the UIKit-based PDFKitView for SwiftUI integration
- **Dismissal control**: Provides close button with consistent styling
- **Full-screen layout**: Maximizes reading area for PDF content

#### PDFKitView

The `PDFKitView` is a `UIViewRepresentable` that bridges UIKit's `PDFView` to SwiftUI:

```swift
struct PDFKitView: UIViewRepresentable {
    let content: Content
    
    func makeUIView(context: Context) -> PDFView {
        let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationUrl = docsUrl.appendingPathComponent("\(content.content_id).pdf")
        
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(url: destinationUrl)
        
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
```

**Key Features**:
- **UIViewRepresentable bridge**: Integrates UIKit's powerful `PDFView` into SwiftUI
- **Auto-scaling**: Automatically adjusts PDF to fit screen width (`autoScales = true`)
- **Continuous scrolling**: Displays pages in a continuous vertical scroll (`.singlePageContinuous`)
- **Direct file access**: Loads PDF directly from Documents directory using content ID
- **Native PDF features**: Inherits all PDFView capabilities (zoom, search, annotations)

**Display Configuration**:
- **displayMode**: `.singlePageContinuous` allows smooth scrolling through pages
- **displayDirection**: `.vertical` for natural top-to-bottom reading
- **autoScales**: Ensures PDF fits screen width while maintaining aspect ratio

This architecture separates concerns:
1. **PDFKitView**: Handles UIKit integration and PDF rendering
2. **PDFViewerContainer**: Manages SwiftUI presentation and controls
3. **DownloadManager**: Provides file location and existence checking

## DownloadManager Deep Dive

The `DownloadManager` is the heart of this application, serving as a single source of truth for all download operations and file state management.

### Design Pattern

`DownloadManager` follows the **Observer pattern** using Combine's `@Published` property wrappers, making it an `ObservableObject` that automatically notifies SwiftUI views of state changes.

### Key Responsibilities

#### 1. **State Management**
```swift
@Published private var downloadingStatus: [Int: Bool] = [:]
@Published private var downloadedStatus: [Int: Bool] = [:]
@Published var downloadProgress: [Int: Double] = [:]
@Published var errorMessage: String?
@Published var showError: Bool = false
```

- **downloadingStatus**: Tracks which content IDs are currently being downloaded
- **downloadedStatus**: In-memory cache of which files exist on disk
- **downloadProgress**: Real-time progress (0.0 to 1.0) for each download
- **errorMessage**: User-facing error descriptions
- **showError**: Boolean to trigger error alert presentation

#### 2. **Initialization & Synchronization**

The `DownloadManager` is initialized in the app's entry point (`DownloadSampleAppApp.swift`) during the app's initialization phase. This ensures a single, shared instance exists throughout the app's lifecycle.

**App-Level Initialization**:

```swift
@main
struct DownloadSampleAppApp: App {
    let sharedModelContainer: ModelContainer
    let downloadManager: DownloadManager

    init() {
        let schema = Schema([Content.self])
        let configuration = ModelConfiguration(
            "MainStore",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.sharedModelContainer = container
            // Create DownloadManager with the ModelContainer
            self.downloadManager = DownloadManager(modelContainer: container)
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .environmentObject(downloadManager)  // Inject as environment object
        }
    }
}
```

**Key Points**:

1. **Single Source of Truth**: Both `sharedModelContainer` and `downloadManager` are created once during app initialization
2. **Shared Context**: The same `ModelContainer` is used for both SwiftData queries and download operations
3. **Environment Injection**: The manager is injected as an `@EnvironmentObject`, making it accessible to all child views
4. **Lifecycle Management**: The manager lives for the entire app session, maintaining state across view changes

**DownloadManager Initialization Process**:

On initialization, the `DownloadManager`:
1. Receives the `ModelContainer` reference from the app
2. Creates its own `ModelContext` from the container for database operations
3. Calls `initializeDownloadStatus()` to sync state with persisted data

```swift
init(modelContainer: ModelContainer) {
    self.modelContainer = modelContainer
    self.context = modelContainer.mainContext
    
    // Initialize download status from persisted data
    self.initializeDownloadStatus()
}

private func initializeDownloadStatus() {
    let descriptor = FetchDescriptor<Content>()
    guard let contents = try? context.fetch(descriptor) else { return }
    
    for content in contents {
        checkFileExists(content: content)
    }
}
```

This architecture ensures that:
- The download status accurately reflects what's stored on disk when the app launches
- All views share the same download manager instance
- Database operations are thread-safe through the shared context
- State changes propagate automatically via Combine's `@Published` properties

#### 3. **Network Connectivity Check**

Before initiating downloads, the manager performs a connectivity check:

```swift
func hasNetworkConnection() -> Bool {
    // Synchronous check using URLSession with timeout
    // Production apps should use Network framework's NWPathMonitor
}
```

**Note**: The current implementation uses a simple URL request. For production, Apple's `Network` framework provides more reliable connectivity monitoring.

#### 4. **Download Process Flow**

The download workflow follows these steps:

```
1. User taps "Download" button
   ↓
2. DownloadManager.downloadFile(content:) called
   ↓
3. Network connectivity verified
   ↓
4. Download status set to "downloading"
   ↓
5. URLSession.downloadTask created and started
   ↓
6. Progress monitored (simplified implementation)
   ↓
7. File downloaded to temporary location
   ↓
8. File moved to app's Documents directory
   ↓
9. Content.isDownloaded updated in SwiftData
   ↓
10. Context saved to persist changes
   ↓
11. UI updated via @Published properties
```

#### 5. **File Storage Strategy**

Files are stored in the app's **Documents directory** with a naming convention based on content ID and type:

```swift
let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

let destinationUrl = content.resourceType == "video" 
    ? docsUrl.appendingPathComponent("\(contentID).mp4")
    : docsUrl.appendingPathComponent("\(contentID).pdf")
```

**Benefits of this approach**:
- Simple file lookup by ID
- Automatic file extension based on content type
- Files persist across app launches
- Backed up by iCloud (can be configured)

#### 6. **Public API**

The manager exposes a clean, minimal API for views:

```swift
// Check download state
func isDownloading(_ content: Content) -> Bool
func isDownloaded(_ content: Content) -> Bool
func getProgress(_ content: Content) -> Double

// Perform actions
func downloadFile(content: Content)
func deleteFile(content: Content)
func checkFileExists(content: Content)

// Retrieve content for playback
func getVideoFileAsset(content: Content) -> AVPlayerItem?
func getPDFView(for content: Content) -> PDFView?
```

#### 7. **Error Handling**

The manager implements comprehensive error handling:

- **Network errors**: Displayed via `errorMessage` and `showError` alert
- **Invalid URLs**: Caught before download attempt
- **File system errors**: Handled during save/delete operations
- **HTTP errors**: Checked via response status codes

```swift
guard response.statusCode == 200 else {
    self.errorMessage = "Download failed for \(content.name)"
    self.showError = true
    return
}
```

#### 8. **Memory Management**

The manager uses:
- `[weak self]` captures in closures to prevent retain cycles
- Proper cleanup in `defer` blocks
- Dictionary-based status tracking (memory-efficient for large content lists)

## SwiftData Integration

### The Content Model

```swift
@Model
final class Content: Identifiable, Codable, Hashable {
    var content_id: Int
    var name: String
    var details: String
    var url: String
    var resourceType: String  // "video" or "pdf"
    var isDownloaded: Bool
}
```

**Key Design Decisions**:

1. **@Model Macro**: Automatically generates SwiftData persistence code
2. **Codable Conformance**: Enables JSON decoding (prepared for API integration)
3. **Identifiable**: Required for SwiftUI ForEach loops
4. **isDownloaded Flag**: Persisted boolean for quick status checks

### SwiftData Setup

The app initializes SwiftData in `DownloadSampleAppApp.swift`:

```swift
init() {
    let schema = Schema([Content.self])
    let configuration = ModelConfiguration(
        "MainStore",
        schema: schema,
        isStoredInMemoryOnly: false  // Persistent storage
    )
    
    let container = try ModelContainer(for: schema, configurations: [configuration])
    self.sharedModelContainer = container
    self.downloadManager = DownloadManager(modelContainer: container)
}
```

**Environment Injection**:
```swift
ContentView()
    .modelContainer(sharedModelContainer)  // For SwiftData queries
    .environmentObject(downloadManager)    // For download operations
```

This dual injection pattern allows:
- Views to access SwiftData context via `@Environment(\.modelContext)`
- Views to access download functionality via `@EnvironmentObject`

### Why SwiftData?

SwiftData provides:
- **Type-safe**: Compile-time checking of model properties
- **Query Support**: Powerful `@Query` macro for automatic UI updates
- **Relationships**: Easy one-to-many, many-to-many modeling
- **Migration**: Built-in schema versioning
- **iCloud Sync**: Optional CloudKit integration

## Current Implementation Status

### What's Implemented

- Full SwiftData model definition with `@Model` macro
- `ModelContainer` and `ModelContext` setup in app initialization
- SwiftData context injection into view hierarchy
- Persistence of `isDownloaded` status to SwiftData store

### Current Limitation: Mock Data Usage

**The app currently uses `Content.mockContents` instead of loading from SwiftData context.**

In `ManageContentsView.swift`:
```swift
var contents: [Content] = Content.mockContents  // ← Using static mock data
```

### To Migrate to Full SwiftData:

Replace the hardcoded array with a SwiftData query:

```swift
struct ManageContentsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var downloadManager: DownloadManager
    
    // Change this:
    // var contents: [Content] = Content.mockContents
    
    // To this:
    @Query private var contents: [Content]
    
    // Rest of the code remains the same...
}
```

**Why Mock Data for Now?**

Mock data provides:
1. **Easy Testing**: No need to populate database manually
2. **Demonstration**: Shows app functionality immediately
3. **Development Speed**: Quick iteration without database concerns
4. **Documentation**: Clear example content for README/demos

**When to Switch?**

Switch to `@Query` when:
- Integrating with a backend API
- Building content management/admin features
- Requiring dynamic content updates
- Deploying to production

## Project Structure

```
DownloadSampleApp/
├── DownloadSampleApp/
│   ├── DownloadSampleAppApp.swift       # App entry + SwiftData initialization
│   ├── Content.swift                     # SwiftData model + mock data
│   ├── DownloadManager.swift            # Download orchestration engine
│   ├── ContentView.swift                # Root navigation container
│   ├── ManageContentsView.swift         # Grid view with search/filter
│   ├── ContentDetailView.swift          # Download controls & content detail
│   ├── VideoView.swift                  # AVKit video player wrapper
│   ├── PDFViewer.swift                  # PDFKit viewer container
│   ├── PDFKitView.swift                 # UIViewRepresentable for PDFView
│   ├── MenuCellView.swift               # Reusable grid cell component
│   └── Assets.xcassets/                 # App icons and colors
└── DownloadSampleApp.xcodeproj/
```

## Usage

### Running the App

1. Open `DownloadSampleApp.xcodeproj` in Xcode 15+
2. Select a simulator or device (iOS 17+)
3. Press `Cmd + R` to build and run

### Testing Downloads

The app includes two mock content items:
- **TestVideo**: Sample MP4 video file
- **TestPDF**: Sample PDF document

**To test**:
1. Tap on any content card in the grid
2. Tap "Download" button
3. Watch progress indicator
4. Once complete, tap "View" to play/read
5. Tap "Delete" to remove from device

### Testing Search & Filters

- Use the search bar to filter by name or description
- Tap filter buttons: **All**, **Videos**, **PDFs**, **Downloaded**
- Downloaded items show a green badge on their cards

## Future Enhancements

### Short Term
- [ ] Implement proper `URLSessionDownloadDelegate` for accurate progress
- [ ] Add background download support for large files
- [ ] Implement download queue with priority management
- [ ] Add storage usage indicator and cleanup tools

### Medium Term
- [ ] Replace mock data with `@Query` for full SwiftData integration
- [ ] Add content CRUD operations (Create, Read, Update, Delete)
- [ ] Implement backend API integration for content fetching
- [ ] Add user authentication and content synchronization

### Long Term
- [ ] CloudKit sync for cross-device content availability
- [ ] Content recommendations based on viewing history
- [ ] Offline-first architecture with conflict resolution
- [ ] Analytics and download performance monitoring

## Technical Requirements

- **Xcode**: 15.0 or later
- **iOS Deployment Target**: 17.0+
- **Swift**: 5.9+
- **Frameworks**: SwiftUI, SwiftData, AVKit, PDFKit, Combine

## Key Learnings & Patterns

This app demonstrates:

1. **SwiftData + ObservableObject Integration**: How to use both persistence and observable state management
2. **File System Management**: Safe download, storage, and deletion patterns
3. **Error Handling**: User-facing error messages with graceful degradation
4. **Progress Tracking**: Real-time UI updates during long-running operations
5. **Search & Filter**: Efficient content filtering with multiple criteria
6. **Offline-First Design**: Local storage with network connectivity awareness
7. **Modern SwiftUI Patterns**: `@Environment`, `@EnvironmentObject`, `@Published`, `@Query`

## Contributing

This is a sample/educational project. Feel free to fork and adapt for your own needs. Some areas for contribution:

- Better progress tracking implementation
- Enhanced error recovery mechanisms
- Unit and UI tests
- Accessibility improvements

## License

This project is provided as-is for educational purposes.

---

**Built with ❤️ using SwiftUI and SwiftData**
