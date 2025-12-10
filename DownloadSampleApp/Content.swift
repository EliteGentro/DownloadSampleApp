//
//  Content.swift
//  Coffey
//
//  Created by Humberto Genaro Cisneros Salinas on 17/10/25.
//


import Foundation
import SwiftData
import System
import Combine

@Model
final class Content: Identifiable, Codable, Hashable  {
    var content_id : Int
    var name: String
    var details : String
    var url : String
    var resourceType: String
    var isDownloaded: Bool
    
    enum CodingKeys: String, CodingKey {
        case name, content_id, details, url, resourceType
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content_id = try container.decode(Int.self, forKey: .content_id)
        self.name = try container.decode(String.self, forKey: .name)
        self.details = try container.decode(String.self, forKey: .details)
        self.url = try container.decode(String.self, forKey: .url)
        self.resourceType = try container.decode(String.self, forKey: .resourceType)
        self.isDownloaded = false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.details, forKey: .details)
        try container.encode(self.url, forKey: .url)
        try container.encode(self.resourceType, forKey: .resourceType)
    }
    
    init(
        content_id: Int,
        name: String,
        details: String,
        url: String,
        resourceType: String,
        isDownloaded :Bool,
    ){
        self.content_id = content_id
        self.name = name
        self.details = details
        self.url = url
        self.resourceType = resourceType
        self.isDownloaded = isDownloaded
    }
    
    static let mockContents: [Content] = [
        Content(content_id: 1, name:"TestVideo", details: "This is a Video to Test Videos.", url: "https://examplefiles.org/files/video/mp4-example-video-download-640x480.mp4", resourceType: "video", isDownloaded: false),
        Content(content_id: 2, name:"TestPDF", details: "This is a PDF to Test PDFs.", url: "https://ontheline.trincoll.edu/images/bookdown/sample-local-pdf.pdf", resourceType: "pdf", isDownloaded: false)
    ]
}
