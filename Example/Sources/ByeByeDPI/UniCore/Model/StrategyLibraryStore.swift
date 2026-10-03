//
//  StrategyLibraryStore.swift
//  PalkaDPI
//

import Foundation
import SwiftUI

struct PalkaStrategyStats: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var commandTemplate: [String]
    var successCount: Int
    var failureCount: Int
    var averageLatencyMilliseconds: Int?
    var lastUsedAt: Date
    var lastSuccessAt: Date?
    var isFavorite: Bool

    var reliability: Double {
        let total = successCount + failureCount
        return total == 0 ? 0 : Double(successCount) / Double(total)
    }
}

final class StrategyLibraryStore: ObservableObject {
    @Published private(set) var records: [PalkaStrategyStats] = []

    private let key = "MuseDPI.strategyLibrary.v1"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: Constants.APP_GROUP_ID) ?? .standard
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([PalkaStrategyStats].self, from: data) {
            records = decoded
        }
    }

    func record(
        strategyID: String,
        name: String,
        commandTemplate: [String],
        succeeded: Bool,
        latencyMilliseconds: Int?
    ) {
        var record = records.first(where: { $0.id == strategyID }) ?? PalkaStrategyStats(
            id: strategyID,
            name: name,
            commandTemplate: commandTemplate,
            successCount: 0,
            failureCount: 0,
            averageLatencyMilliseconds: nil,
            lastUsedAt: Date(),
            lastSuccessAt: nil,
            isFavorite: false
        )

        record.name = name
        record.commandTemplate = commandTemplate
        record.lastUsedAt = Date()
        if succeeded {
            record.successCount += 1
            record.lastSuccessAt = Date()
            if let latency = latencyMilliseconds {
                if let previous = record.averageLatencyMilliseconds {
                    record.averageLatencyMilliseconds = Int((Double(previous) * 0.7) + (Double(latency) * 0.3))
                } else {
                    record.averageLatencyMilliseconds = latency
                }
            }
        } else {
            record.failureCount += 1
        }

        records.removeAll { $0.id == strategyID }
        records.insert(record, at: 0)
        records = Array(records.prefix(40))
        persist()
    }

    func toggleFavorite(strategy: OnlineStrategy) {
        var record = records.first(where: { $0.id == strategy.id }) ?? PalkaStrategyStats(
            id: strategy.id,
            name: strategy.displayName,
            commandTemplate: strategy.commandArgs,
            successCount: 0,
            failureCount: 0,
            averageLatencyMilliseconds: nil,
            lastUsedAt: Date(),
            lastSuccessAt: nil,
            isFavorite: false
        )
        record.name = strategy.displayName
        record.commandTemplate = strategy.commandArgs
        record.isFavorite.toggle()
        records.removeAll { $0.id == strategy.id }
        records.insert(record, at: 0)
        persist()
    }

    func isFavorite(_ strategyID: String) -> Bool {
        records.first(where: { $0.id == strategyID })?.isFavorite == true
    }

    func removeHistory(_ strategyID: String) {
        guard let record = records.first(where: { $0.id == strategyID }) else { return }
        if record.isFavorite {
            var favorite = record
            favorite.successCount = 0
            favorite.failureCount = 0
            favorite.averageLatencyMilliseconds = nil
            favorite.lastSuccessAt = nil
            records.removeAll { $0.id == strategyID }
            records.append(favorite)
        } else {
            records.removeAll { $0.id == strategyID }
        }
        persist()
    }

    func bestFallback(excluding strategyID: String) -> PalkaStrategyStats? {
        records
            .filter { $0.id != strategyID && !$0.commandTemplate.isEmpty && $0.successCount > 0 }
            .sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
                if $0.reliability != $1.reliability { return $0.reliability > $1.reliability }
                return ($0.averageLatencyMilliseconds ?? .max) < ($1.averageLatencyMilliseconds ?? .max)
            }
            .first
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(records), forKey: key)
    }
}
