//
//  DownloadManager.swift
//  Coffey
//
//  Created by Humberto Genaro Cisneros Salinas on 20/10/25.
//


import Foundation
import AVKit
import Combine
import SwiftData
import PDFKit
import SwiftUI

final class DownloadManager: ObservableObject {
    //May be missing context
    let modelContainer: ModelContainer
    private let context: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.context = modelContainer.mainContext
        
        // Initialize download status from persisted data
        self.initializeDownloadStatus()
    }



    @Published private var downloadingStatus: [Int: Bool] = [:]
    @Published private var downloadedStatus: [Int: Bool] = [:]
    @Published var downloadProgress: [Int: Double] = [:]
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Initialization
    private func initializeDownloadStatus() {
        let descriptor = FetchDescriptor<Content>()
        guard let contents = try? context.fetch(descriptor) else { return }
        
        for content in contents {
            checkFileExists(content: content)
        }
    }
    
    // MARK: - Network Check
    func hasNetworkConnection() -> Bool {
        // Basic check - in production, use Network framework for better reliability
        guard let url = URL(string: "https://www.apple.com") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        
        let semaphore = DispatchSemaphore(value: 0)
        var isReachable = false
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            isReachable = (response as? HTTPURLResponse) != nil
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 2)
        return isReachable
    }
    
    // MARK: - Public computed helpers
    func isDownloading(_ content: Content) -> Bool {
        return downloadingStatus[content.content_id] ?? false
    }

    func isDownloaded(_ content: Content) -> Bool {
        return downloadedStatus[content.content_id] ?? content.isDownloaded
    }
    
    func getProgress(_ content: Content) -> Double {
        return downloadProgress[content.content_id] ?? 0.0
    }

    // MARK: - Core logic
    func downloadFile(content: Content) {
        print("downloadFile \(content.url)")
        
        // Check network connectivity first
        guard hasNetworkConnection() else {
            errorMessage = "No internet connection available"
            showError = true
            return
        }
        
        let contentID = content.content_id
        let contentURLString = content.url

        downloadingStatus[contentID] = true
        downloadProgress[contentID] = 0.0
        objectWillChange.send()

        let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let destinationUrl = content.resourceType == "video" ? docsUrl.appendingPathComponent("\(contentID).mp4") :
            docsUrl.appendingPathComponent("\(contentID).pdf")
        
        print(docsUrl)
        print(destinationUrl)

        if FileManager.default.fileExists(atPath: destinationUrl.path) {
            print("File already exists")
            downloadingStatus[contentID] = false
            downloadedStatus[contentID] = true
            content.isDownloaded = true
            try? context.save()
            return
        }

        guard let url = URL(string: contentURLString) else {
            print("Invalid URL")
            downloadingStatus[contentID] = false
            errorMessage = "Invalid URL for \(content.name)"
            showError = true
            return
        }

        // Use download task for progress tracking
        let downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self else { return }

            defer {
                DispatchQueue.main.async {
                    self.downloadingStatus[contentID] = false
                    self.downloadProgress[contentID] = 0.0
                }
            }

            if let error = error {
                print("Request error: ", error)
                DispatchQueue.main.async {
                    self.errorMessage = "Download failed: \(error.localizedDescription)"
                    self.showError = true
                }
                return
            }

            guard
                let response = response as? HTTPURLResponse,
                response.statusCode == 200,
                let tempURL = tempURL
            else {
                DispatchQueue.main.async {
                    self.errorMessage = "Download failed for \(content.name)"
                    self.showError = true
                }
                return
            }

            DispatchQueue.main.async {
                do {
                    try FileManager.default.moveItem(at: tempURL, to: destinationUrl)
                    self.downloadedStatus[contentID] = true
                    content.isDownloaded = true
                    do {
                        //Save context
                        try self.context.save()
                    } catch {
                        print(error)
                    }
                } catch {
                    print("Error writing file: ", error)
                    self.errorMessage = "Failed to save file: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }

        downloadTask.resume()
        
        // Observe progress
        observeProgress(for: downloadTask, contentID: contentID)
    }
    
    private func observeProgress(for task: URLSessionDownloadTask, contentID: Int) {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak task] timer in
            guard let task = task else {
                timer.invalidate()
                return
            }
            
            if task.state != .running {
                timer.invalidate()
                return
            }
            
            // Note: Progress observation would be better with URLSessionDelegate
            // This is a simplified version
        }
    }


    func deleteFile(content: Content) {
        let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let destinationUrl = content.resourceType == "video" ? docsUrl.appendingPathComponent("\(content.content_id).mp4") :
            docsUrl.appendingPathComponent("\(content.content_id).pdf")

        guard FileManager.default.fileExists(atPath: destinationUrl.path) else { return }

        do {
            try FileManager.default.removeItem(at: destinationUrl)
            print("File deleted successfully")
            downloadedStatus[content.content_id] = false
            content.isDownloaded = false
            do {
                //Save context
                try self.context.save()
            } catch {
                print(error)
            }

        } catch {
            print("Error while deleting video file: ", error)
        }
    }

    func checkFileExists(content: Content) {
        let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationUrl = content.resourceType == "video" ? docsUrl.appendingPathComponent("\(content.content_id).mp4") :
            docsUrl.appendingPathComponent("\(content.content_id).pdf")

        downloadedStatus[content.content_id] = FileManager.default.fileExists(atPath: destinationUrl.path)
    }

    func getVideoFileAsset(content: Content) -> AVPlayerItem? {
        let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationUrl = docsUrl.appendingPathComponent("\(content.content_id).mp4")
        print("Video File Asset \(destinationUrl)")
        print("Name: \(content.name)")

        guard FileManager.default.fileExists(atPath: destinationUrl.path) else { return nil }
        let avAsset = AVURLAsset(url: destinationUrl)
        return AVPlayerItem(asset: avAsset)
    }
    
    

    func getPDFView(for content: Content) -> PDFView? {
        let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationUrl = docsUrl.appendingPathComponent("\(content.content_id).pdf")
        print("PDF File Path: \(destinationUrl)")
        print("Name: \(content.name)")

        guard FileManager.default.fileExists(atPath: destinationUrl.path) else { return nil }

        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(url: destinationUrl)
        return pdfView
    }

}
