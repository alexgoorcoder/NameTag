import Foundation
import CryptoKit

final class ContactKeyStore {
    private let keychain: KeychainService

    private static let sharedKeyPrefix = "contact.sharedKey."
    private static let broadcastSecretPrefix = "contact.broadcastSecret."
    private static let contactListKey = "contact.knownUIDs"

    init(keychainService: KeychainService) {
        self.keychain = keychainService
    }

    // MARK: - Shared Keys (ECDH-derived, per-contact)

    func storeSharedKey(forContact uid: String, key: SymmetricKey) throws {
        let data = CryptoService.serializeSymmetricKey(key)
        try keychain.save(key: Self.sharedKeyPrefix + uid, data: data)
        trackContact(uid: uid)
    }

    func sharedKey(forContact uid: String) -> SymmetricKey? {
        guard let data = keychain.load(key: Self.sharedKeyPrefix + uid) else { return nil }
        return CryptoService.deserializeSymmetricKey(data)
    }

    // MARK: - Broadcast Secrets (exchanged during handshake)

    func storeBroadcastSecret(forContact uid: String, secret: Data) throws {
        try keychain.save(key: Self.broadcastSecretPrefix + uid, data: secret)
        trackContact(uid: uid)
    }

    func broadcastSecret(forContact uid: String) -> Data? {
        keychain.load(key: Self.broadcastSecretPrefix + uid)
    }

    /// Returns all known contact UIDs and their broadcast secrets for identifier resolution.
    func allBroadcastSecrets() -> [(uid: String, secret: Data)] {
        let uids = knownContactUIDs()
        return uids.compactMap { uid in
            guard let secret = broadcastSecret(forContact: uid) else { return nil }
            return (uid: uid, secret: secret)
        }
    }

    // MARK: - Cleanup

    func deleteKeys(forContact uid: String) {
        keychain.delete(key: Self.sharedKeyPrefix + uid)
        keychain.delete(key: Self.broadcastSecretPrefix + uid)
        untrackContact(uid: uid)
    }

    func deleteAll() {
        for uid in knownContactUIDs() {
            keychain.delete(key: Self.sharedKeyPrefix + uid)
            keychain.delete(key: Self.broadcastSecretPrefix + uid)
        }
        keychain.delete(key: Self.contactListKey)
    }

    // MARK: - Contact UID Tracking

    private func knownContactUIDs() -> [String] {
        guard let data = keychain.load(key: Self.contactListKey),
              let uids = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return uids
    }

    private func trackContact(uid: String) {
        var uids = knownContactUIDs()
        guard !uids.contains(uid) else { return }
        uids.append(uid)
        if let data = try? JSONEncoder().encode(uids) {
            try? keychain.save(key: Self.contactListKey, data: data)
        }
    }

    private func untrackContact(uid: String) {
        var uids = knownContactUIDs()
        uids.removeAll { $0 == uid }
        if let data = try? JSONEncoder().encode(uids) {
            try? keychain.save(key: Self.contactListKey, data: data)
        }
    }
}
