//
//  SortOption.swift
//  EcoJournal
//
//  Created by David Contreras on 5/13/26.
//

import Foundation

// MARK: - Shared protocol for FilterSheet

protocol FilterDisplayable: CaseIterable, Identifiable, Equatable {
    var rawValue: String { get }
    var systemImage: String { get }
    var subtitle: String? { get }
}

// MARK: - Dashboard (journals)

enum SortOption: String, CaseIterable, Identifiable, FilterDisplayable {
    case mostRecent = "Most Recent"
    case oldestFirst = "Oldest First"
    case aToZ = "A → Z"
    case zToA = "Z → A"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .mostRecent:   return "clock.arrow.circlepath"
        case .oldestFirst:  return "clock"
        case .aToZ:         return "arrow.up"
        case .zToA:         return "arrow.down"
        }
    }

    var subtitle: String? { nil }
}

// MARK: - Logs list

enum LogSortOption: String, CaseIterable, Identifiable, FilterDisplayable {
    case creationDate = "Creation Date"
    case aToZ = "A → Z"
    case zToA = "Z → A"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .creationDate: return "clock.arrow.circlepath"
        case .aToZ:         return "arrow.up"
        case .zToA:         return "arrow.down"
        }
    }

    var subtitle: String? {
        switch self {
        case .creationDate: return "By date created"
        case .aToZ, .zToA:  return nil
        }
    }
}
