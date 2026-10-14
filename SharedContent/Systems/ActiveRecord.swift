//
//  ActiveRecord.swift
//  Kencana
//
//  Created by Saujana Shafi on 21/03/26.
//

import SwiftData

@MainActor
protocol ActiveRecord: PersistentModel {
    // Instance-level CRUD operations.
    func save() throws
    func delete() throws

    // Static fetch operations.
    static func fetchAll() throws -> Set<Self>
    static func find(byID id: Self.ID) throws -> Self?
}

extension ActiveRecord {
    func save() throws {
        let repository = GenericRepository<Self>()
        try repository.add(self)
    }

    func delete() throws {
        let repository = GenericRepository<Self>()
        if let model = try? repository.fetch(byID: self.id) {
            try repository.delete(model)
        }
    }

    static func fetchAll() throws -> Set<Self> {
        let repository = GenericRepository<Self>()
        return try repository.fetchAll()
    }

    static func find(byID id: Self.ID) throws -> Self? {
        let repository = GenericRepository<Self>()
        return try repository.fetch(byID: id)
    }
}
