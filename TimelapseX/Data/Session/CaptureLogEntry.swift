//
//  CaptureLogEntry.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import Foundation

struct CaptureLogEntry: Codable {
    let timestamp: Date
    let sequenceNumber: Int
    let outcome: CaptureOutcome
    let errorDescription: String?

    enum CaptureOutcome: String, Codable {
        case success
        case captureFailed
    }
}
