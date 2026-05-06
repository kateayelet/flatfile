//
//  AIService.swift
//  FlatFile
//
//  Anthropic API calls for AI capture mode
//

import Foundation

enum AIService {
    static func captureRow(from input: String, headers: [String]) async throws -> [String] {
        Array(headers.enumerated().map { index, _ in
            index == 0 ? input : ""
        })
    }
}
