//
//  DataBase.swift
//  Kencana
//
//  Created by Saujana Shafi on 21/03/26.
//

@MainActor
class DataBase {
    // A shared singleton instance to ensure a single, consistent persistence configuration.
    static var shared: DataBase = .init()

    // The persistence stack that holds the ModelContainer and ModelContext.
    var persistenceStack: PersistenceStack

    // Private initializer to prevent multiple instances.
    private init() {
        do {
            // Initialize the persistence stack with a list of model types.
            self.persistenceStack = try PersistenceStack(
                modelTypes: [
                    SessionModel.self,
                    SongModel.self,
                    SectionModel.self,
                    SetlistEntryModel.self,
                    MarkerModel.self,
                ],
                isMemoryOnly: false
            )
        } catch {
            // If the persistent store fails to load, fail fast with a clear message.
            fatalError("Failed to initialize PersistenceStack: \(error)")
        }
    }
}
