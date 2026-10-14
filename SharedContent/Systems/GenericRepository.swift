//
//  GenericRepository.swift
//  Kencana
//
//  Created by Saujana Shafi on 21/03/26.
//

import SwiftData

class GenericRepository<Model: PersistentModel>: Repository {
    // The repository uses a shared persistence stack from the DataBase singleton.
    var persistenceStack: PersistenceStack = DataBase.shared.persistenceStack
}
