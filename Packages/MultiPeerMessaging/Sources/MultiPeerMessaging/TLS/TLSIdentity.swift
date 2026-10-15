/* Derived from Apple's PeerToPeerMessaging sample. See LICENSE.txt. */
import Foundation
import Crypto
import Security
import SwiftASN1
import X509
import Synchronization

/// Serializes local keychain identity retrieval and creation across servers and clients.
final class TLSIdentity: Sendable {
    static let shared = TLSIdentity()
    private let lock = Mutex(())

    func identity(for peerID: UUID) throws -> sec_identity_t {
        try lock.withLock { _ in try createIdentity(for: peerID) }
    }

    private func createIdentity(for peerID: UUID) throws -> sec_identity_t {
        let label = peerID.uuidString
        let query: [String: Any] = [kSecClass as String: kSecClassIdentity,
                                   kSecAttrLabel as String: label, kSecReturnRef as String: true]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let item {
            guard let identity = sec_identity_create(item as! SecIdentity) else {
                throw MessagingError.identityUnavailable
            }
            return identity
        }
        guard status == errSecItemNotFound else { throw MessagingError.identityUnavailable }

        let key = Crypto.P256.Signing.PrivateKey()
        let subject = try DistinguishedName { CommonName(label) }
        let certificate = try Certificate(
            version: .v3, serialNumber: Certificate.SerialNumber(),
            publicKey: Certificate.PublicKey(key.publicKey),
            notValidBefore: Date().addingTimeInterval(-60),
            notValidAfter: Date().addingTimeInterval(365 * 24 * 60 * 60),
            issuer: subject, subject: subject, signatureAlgorithm: .ecdsaWithSHA256,
            extensions: try Certificate.Extensions {
                Critical(BasicConstraints.notCertificateAuthority)
                Critical(KeyUsage(digitalSignature: true))
                try ExtendedKeyUsage([.serverAuth, .clientAuth])
            }, issuerPrivateKey: Certificate.PrivateKey(key))
        var serializer = DER.Serializer()
        try serializer.serialize(certificate)
        guard let secCertificate = SecCertificateCreateWithData(nil, Data(serializer.serializedBytes) as CFData),
              let secKey = SecKeyCreateWithData(key.x963Representation as CFData, [
                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate
              ] as CFDictionary, nil) else { throw MessagingError.identityUnavailable }
        let keyQuery: [String: Any] = [kSecClass as String: kSecClassKey,
            kSecAttrLabel as String: label, kSecValueRef as String: secKey,
            kSecAttrApplicationTag as String: Data(label.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        guard SecItemAdd(keyQuery as CFDictionary, nil) == errSecSuccess else {
            throw MessagingError.identityUnavailable
        }
        let certificateQuery: [String: Any] = [kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: label, kSecValueRef as String: secCertificate]
        guard SecItemAdd(certificateQuery as CFDictionary, nil) == errSecSuccess else {
            SecItemDelete(keyQuery as CFDictionary)
            throw MessagingError.identityUnavailable
        }
        item = nil
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let item,
              let identity = sec_identity_create(item as! SecIdentity) else {
            throw MessagingError.identityUnavailable
        }
        return identity
    }

}
