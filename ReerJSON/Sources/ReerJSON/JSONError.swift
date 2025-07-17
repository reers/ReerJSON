//
//  JSONError.swift
//  ReerJSON
//
//  Created by phoenix on 2025/7/17.
//


enum JSONError: Swift.Error, Equatable {
    case readJSONDocumentFailed
    
    var debugDescription : String {
        switch self {
        case .readJSONDocumentFailed:
            return "Unable to read data by yyjson."
        }
    }
}
