//
//  PDFViewer.swift
//  Coffey
//
//  Created by Humberto Genaro Cisneros Salinas on 13/11/25.
//

import Foundation
import SwiftUI
import PDFKit
import SwiftData

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
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                    .padding()
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Content.self)
    let mockManager = DownloadManager(modelContainer: container)
    
    PDFViewerContainer(content: Content.mockContents.last!)
        .modelContainer(container)
        .environmentObject(mockManager)
}
