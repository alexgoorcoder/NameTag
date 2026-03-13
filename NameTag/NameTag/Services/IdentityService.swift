import Foundation
import CryptoKit
import Security

@Observable
final class IdentityService {
    private(set) var currentUID: String
    private(set) var identityKeyPair: P256.KeyAgreement.PrivateKey
    private(set) var broadcastSecret: Data

    private let keychainService: KeychainService

    private static let uidKeychainKey = "identity.uid"
    private static let keyPairKeychainKey = "identity.keyPair"
    private static let broadcastSecretKeychainKey = "identity.broadcastSecret"
    private static let onboardedKeychainKey = "identity.onboarded"

    var isOnboarded: Bool {
        get { keychainService.load(key: Self.onboardedKeychainKey) != nil }
        set {
            if newValue {
                try? keychainService.save(key: Self.onboardedKeychainKey, data: Data([1]))
            } else {
                keychainService.delete(key: Self.onboardedKeychainKey)
            }
        }
    }

    /// X9.63 representation of the public key for BLE exchange.
    var publicKeyData: Data {
        CryptoService.serializePublicKey(identityKeyPair.publicKey)
    }

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService

        // Load or generate UID
        if let uidData = keychainService.load(key: Self.uidKeychainKey),
           let uid = String(data: uidData, encoding: .utf8) {
            currentUID = uid
        } else {
            let uid = UUID().uuidString
            try? keychainService.save(key: Self.uidKeychainKey, data: Data(uid.utf8))
            currentUID = uid
        }

        // Load or generate identity key pair
        if let keyData = keychainService.load(key: Self.keyPairKeychainKey),
           let key = try? CryptoService.deserializePrivateKey(keyData) {
            identityKeyPair = key
        } else {
            let key = CryptoService.generateIdentityKeyPair()
            try? keychainService.save(key: Self.keyPairKeychainKey,
                                       data: CryptoService.serializePrivateKey(key))
            identityKeyPair = key
        }

        // Load or generate broadcast secret
        if let secret = keychainService.load(key: Self.broadcastSecretKeychainKey),
           secret.count == 32 {
            broadcastSecret = secret
        } else {
            let secret = CryptoService.generateBroadcastSecret()
            try? keychainService.save(key: Self.broadcastSecretKeychainKey, data: secret)
            broadcastSecret = secret
        }
    }

    func resetIdentity() {
        keychainService.delete(key: Self.uidKeychainKey)
        keychainService.delete(key: Self.keyPairKeychainKey)
        keychainService.delete(key: Self.broadcastSecretKeychainKey)
        keychainService.delete(key: Self.onboardedKeychainKey)

        let newUID = UUID().uuidString
        try? keychainService.save(key: Self.uidKeychainKey, data: Data(newUID.utf8))
        currentUID = newUID

        let newKey = CryptoService.generateIdentityKeyPair()
        try? keychainService.save(key: Self.keyPairKeychainKey,
                                   data: CryptoService.serializePrivateKey(newKey))
        identityKeyPair = newKey

        let newSecret = CryptoService.generateBroadcastSecret()
        try? keychainService.save(key: Self.broadcastSecretKeychainKey, data: newSecret)
        broadcastSecret = newSecret
    }
}
