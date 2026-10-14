/* Derived from Apple's PeerToPeerMessaging sample. See LICENSE.txt. */
import Foundation
import CryptoKit
import Security
import Synchronization
import X509

/// Serializes TOFU fingerprint lookup and storage across servers and clients.
final class CertificateTrustManager: Sendable {
    static let shared = CertificateTrustManager()
    private let trustService = "MultiPeerMessaging.trusted-certificates"
    private let lock = Mutex(())

    func verify(_ trustResult: sec_trust_t) -> Bool {
        lock.withLock { _ in verifyLocked(trustResult) }
    }

    private func verifyLocked(_ trustResult: sec_trust_t) -> Bool {
        let trust = sec_trust_copy_ref(trustResult).takeRetainedValue()
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let certificate = chain.first,
              let subject = SecCertificateCopySubjectSummary(certificate) as String?,
              UUID(uuidString: subject) != nil else { return false }
        let data = SecCertificateCopyData(certificate) as Data
        // Check dates even though system CA validation is intentionally replaced by TOFU.
        guard let parsed = try? Certificate(derEncoded: Array(data)),
              parsed.notValidBefore <= Date(), parsed.notValidAfter > Date() else { return false }
        let fingerprint = Data(CryptoKit.SHA256.hash(data: data))
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trustService, kSecAttrAccount as String: subject]
        var lookup = query
        lookup[kSecReturnData as String] = true
        var stored: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &stored)
        if status == errSecSuccess { return stored as? Data == fingerprint }
        guard status == errSecItemNotFound else { return false }
        var insertion = query
        insertion[kSecValueData as String] = fingerprint
        insertion[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(insertion as CFDictionary, nil) == errSecSuccess
    }
}

// MARK: - Authenticated peer identity
extension CertificateTrustManager {
    static func peerID(on connection: QuicConnection) throws -> UUID {
        var peerID: UUID?
        sec_protocol_metadata_access_peer_certificate_chain(connection.securityProtocolMetadata) { certificate in
            if peerID == nil {
                let certificate = sec_certificate_copy_ref(certificate).takeRetainedValue()
                if let subject = SecCertificateCopySubjectSummary(certificate) as String? {
                    peerID = UUID(uuidString: subject)
                }
            }
        }
        guard let peerID else { throw MessagingError.invalidHandshake }
        return peerID
    }
}
