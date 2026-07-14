//
//  SessionStatus.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import Foundation

enum SessionStatus: String, Codable {
    case active
    case closed
    case saved
    case discarded
}
