public enum MessagingError: Error, Sendable, Equatable {
    case invalidConfiguration
    case alreadyRunning
    case notConnected
    case identityUnavailable
    case invalidHandshake
    case handshakeTimedOut
    case duplicatePeer
    case clientLimitReached
    case transport(String)
}

// MARK: - Internal error conversion
func messagingError(_ error: any Error) -> MessagingError {
    (error as? MessagingError) ?? .transport(String(describing: error))
}
