import Foundation
import CryptoKit

enum CryptoService {

    // MARK: - Key Generation

    static func generateIdentityKeyPair() -> P256.KeyAgreement.PrivateKey {
        P256.KeyAgreement.PrivateKey()
    }

    static func generateDeviceEncryptionKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    static func generateBroadcastSecret() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        return Data(bytes)
    }

    // MARK: - ECDH Key Agreement

    static func deriveSharedSecret(
        myKey: P256.KeyAgreement.PrivateKey,
        theirPublicKey: P256.KeyAgreement.PublicKey
    ) throws -> SymmetricKey {
        let shared = try myKey.sharedSecretFromKeyAgreement(with: theirPublicKey)
        return shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data("NameTag-v1".utf8),
            sharedInfo: Data(),
            outputByteCount: 32
        )
    }

    // MARK: - AES-GCM Encryption

    static func encrypt(data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        return combined
    }

    static func decrypt(data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - Rotating Broadcast Identifiers

    /// Generates a 16-byte rotating identifier from a broadcast secret and UID.
    /// The identifier changes every `rotationWindowSeconds` (15 minutes).
    static func generateBroadcastIdentifier(secret: Data, uid: String, window: Int) -> Data {
        let message = Data(uid.utf8) + withUnsafeBytes(of: window.bigEndian) { Data($0) }
        let key = SymmetricKey(data: secret)
        let mac = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return Data(mac.prefix(16))
    }

    /// Returns the current 15-minute time window index.
    static func currentWindow(rotationSeconds: Int = 900) -> Int {
        Int(Date().timeIntervalSince1970) / rotationSeconds
    }

    // MARK: - Key Serialization

    static func serializePublicKey(_ key: P256.KeyAgreement.PublicKey) -> Data {
        key.x963Representation
    }

    static func deserializePublicKey(_ data: Data) throws -> P256.KeyAgreement.PublicKey {
        try P256.KeyAgreement.PublicKey(x963Representation: data)
    }

    static func serializePrivateKey(_ key: P256.KeyAgreement.PrivateKey) -> Data {
        key.rawRepresentation
    }

    static func deserializePrivateKey(_ data: Data) throws -> P256.KeyAgreement.PrivateKey {
        try P256.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    static func serializeSymmetricKey(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }

    static func deserializeSymmetricKey(_ data: Data) -> SymmetricKey {
        SymmetricKey(data: data)
    }
}

enum CryptoError: LocalizedError {
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Encryption failed: could not create sealed box"
        }
    }
}
