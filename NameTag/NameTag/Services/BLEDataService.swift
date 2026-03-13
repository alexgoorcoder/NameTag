import Foundation
import CoreBluetooth
import CryptoKit

/// Packet types for BLE data exchange
enum BLEPacketType: UInt8, Codable {
    case handshakeRequest = 1
    case handshakeAccept = 2
    case profileData = 3
    case message = 4
    case messageAck = 5
    case profileSync = 6
}

/// Generic BLE packet for data exchange.
/// Wire format: [1-byte type][encrypted payload] for authenticated packets,
/// [1-byte type][plaintext JSON payload] for handshake packets (pre-key-exchange).
struct BLEPacket: Codable {
    let type: BLEPacketType
    let senderUID: String
    let payload: Data
}

/// Payload for handshake exchange — includes crypto material
struct HandshakePayload: Codable {
    let uid: String
    let firstName: String
    let lastName: String
    let profileVersion: Int
    let publicKey: Data        // ECDH P256 public key (x963 representation)
    let broadcastSecret: Data  // 32-byte random secret for rotating BLE identifiers
}

/// Payload for message delivery
struct MessagePayload: Codable {
    let messageID: String
    let text: String
    let sentAt: Date
    let senderName: String
    let senderPhotoFileName: String?
}

/// Payload for message acknowledgment
struct MessageAckPayload: Codable {
    let messageIDs: [String]
}

/// Payload for profile sync
struct ProfileSyncPayload: Codable {
    let firstName: String
    let lastName: String
    let profileVersion: Int
    let photoFileName: String?
}

/// Manages BLE-based P2P data exchange: handshake, messaging, and profile sync.
/// Works alongside BLEService (proximity) — this service handles the data layer.
@Observable
final class BLEDataService: NSObject, @unchecked Sendable {
    // Dependencies
    private var localContactsService: LocalContactsService?
    private var localMessagingService: LocalMessagingService?
    private var localUserService: LocalUserService?
    private var photoStorageService: PhotoStorageService?
    private var contactKeyStore: ContactKeyStore?
    private var identityKeyPair: P256.KeyAgreement.PrivateKey?
    private var myPublicKeyData: Data = Data()
    private var myBroadcastSecret: Data = Data()
    private var currentUID: String = ""

    // Replay protection: per-contact monotonic counter
    private var lastSeenCounter: [String: UInt64] = [:]
    private var sendCounter: [String: UInt64] = [:]

    // Handshake state
    private(set) var isInHandshakeMode = false
    private(set) var discoveredHandshakePeers: [DiscoveredPeer] = []

    // BLE managers for data exchange
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var dataService: CBMutableService?

    // Track connected peripherals for data exchange
    private var connectedPeripherals: [UUID: CBPeripheral] = [:]
    private var peripheralUIDs: [UUID: String] = [:]

    // Callbacks
    var onHandshakePeerDiscovered: ((DiscoveredPeer) -> Void)?
    var onMessageReceived: ((String, String) -> Void)?  // (senderUID, messageID)

    func configure(
        currentUID: String,
        localContactsService: LocalContactsService,
        localMessagingService: LocalMessagingService,
        localUserService: LocalUserService,
        photoStorageService: PhotoStorageService,
        contactKeyStore: ContactKeyStore,
        identityKeyPair: P256.KeyAgreement.PrivateKey,
        publicKeyData: Data,
        broadcastSecret: Data
    ) {
        self.currentUID = currentUID
        self.localContactsService = localContactsService
        self.localMessagingService = localMessagingService
        self.localUserService = localUserService
        self.photoStorageService = photoStorageService
        self.contactKeyStore = contactKeyStore
        self.identityKeyPair = identityKeyPair
        self.myPublicKeyData = publicKeyData
        self.myBroadcastSecret = broadcastSecret
    }

    // MARK: - Handshake Mode

    func enterHandshakeMode() {
        isInHandshakeMode = true
        discoveredHandshakePeers = []
    }

    func exitHandshakeMode() {
        isInHandshakeMode = false
        discoveredHandshakePeers = []
    }

    /// Build a handshake payload containing our identity + crypto material
    func buildHandshakePayload() -> HandshakePayload? {
        guard let profile = localUserService?.currentProfile else { return nil }
        return HandshakePayload(
            uid: currentUID,
            firstName: profile.firstName,
            lastName: profile.lastName,
            profileVersion: profile.profileVersion,
            publicKey: myPublicKeyData,
            broadcastSecret: myBroadcastSecret
        )
    }

    /// After confirming a contact, derive and store the shared encryption key.
    func completeHandshake(with peer: DiscoveredPeer) throws {
        guard let identityKey = identityKeyPair,
              let keyStore = contactKeyStore else {
            throw BLEDataError.notConfigured
        }

        // Derive shared key via ECDH
        let peerPublicKey = try CryptoService.deserializePublicKey(peer.publicKeyData)
        let sharedKey = try CryptoService.deriveSharedSecret(
            myKey: identityKey,
            theirPublicKey: peerPublicKey
        )
        try keyStore.storeSharedKey(forContact: peer.uid, key: sharedKey)

        // Store the peer's broadcast secret for resolving their rotating BLE identifier
        if let secret = peer.broadcastSecretData {
            try keyStore.storeBroadcastSecret(forContact: peer.uid, secret: secret)
        }
    }

    // MARK: - Message Delivery

    /// Attempt to deliver pending messages to a nearby contact.
    func deliverPendingMessages(to contactUID: String) {
        guard let messagingService = localMessagingService else { return }

        let pending = messagingService.pendingMessages(for: contactUID)
        guard !pending.isEmpty else { return }

        print("[BLEDataService] Would deliver \(pending.count) encrypted messages to \(contactUID)")
    }

    /// Handle receiving a message from BLE
    func handleReceivedMessage(packet: BLEPacket) {
        guard let messagingService = localMessagingService,
              let contactsService = localContactsService else { return }

        guard let payload = try? JSONDecoder().decode(MessagePayload.self, from: packet.payload) else {
            return
        }

        // Only accept messages from known contacts
        guard contactsService.allConnectionUIDs.contains(packet.senderUID) else { return }

        do {
            try messagingService.receiveMessage(
                messageID: payload.messageID,
                from: packet.senderUID,
                text: payload.text,
                sentAt: payload.sentAt,
                senderName: payload.senderName,
                senderPhotoFileName: payload.senderPhotoFileName
            )
            onMessageReceived?(packet.senderUID, payload.messageID)
        } catch {
            print("[BLEDataService] Failed to store received message: \(error)")
        }
    }

    /// Handle receiving a message ACK from BLE
    func handleMessageAck(packet: BLEPacket) {
        guard let messagingService = localMessagingService else { return }

        guard let payload = try? JSONDecoder().decode(MessageAckPayload.self, from: packet.payload) else {
            return
        }

        do {
            try messagingService.markDelivered(messageIDs: payload.messageIDs)
        } catch {
            print("[BLEDataService] Failed to mark messages delivered: \(error)")
        }
    }

    // MARK: - Profile Sync

    func syncProfileIfNeeded(for contactUID: String) {
        guard let contactsService = localContactsService,
              let userService = localUserService else { return }

        guard let contact = contactsService.contacts.first(where: { $0.contactUID == contactUID }),
              let myProfile = userService.currentProfile else { return }

        print("[BLEDataService] Would check profile sync for \(contactUID), local version: \(contact.lastSyncedProfileVersion), my version: \(myProfile.profileVersion)")
    }

    func handleProfileSync(packet: BLEPacket) {
        guard let contactsService = localContactsService else { return }

        guard let payload = try? JSONDecoder().decode(ProfileSyncPayload.self, from: packet.payload) else {
            return
        }

        do {
            try contactsService.updateContactProfile(
                uid: packet.senderUID,
                firstName: payload.firstName,
                lastName: payload.lastName,
                photoFileName: payload.photoFileName
            )
            try contactsService.updateLastSyncedVersion(
                uid: packet.senderUID,
                version: payload.profileVersion
            )
        } catch {
            print("[BLEDataService] Failed to update contact profile: \(error)")
        }
    }

    // MARK: - Encrypted Packet Encoding/Decoding

    /// Encode a packet with AES-GCM encryption for a specific contact.
    func encodeEncryptedPacket(type: BLEPacketType, payload: Data, forContact uid: String) -> Data? {
        guard let keyStore = contactKeyStore,
              let sharedKey = keyStore.sharedKey(forContact: uid) else {
            print("[BLEDataService] No shared key for \(uid), cannot encrypt")
            return nil
        }

        // Increment send counter for replay protection
        let counter = (sendCounter[uid] ?? 0) + 1
        sendCounter[uid] = counter

        // Prepend counter to payload before encryption
        var counterPayload = withUnsafeBytes(of: counter.bigEndian) { Data($0) }
        counterPayload.append(payload)

        guard let encrypted = try? CryptoService.encrypt(data: counterPayload, key: sharedKey) else {
            return nil
        }

        // Wire format: [type byte][senderUID length byte][senderUID][encrypted data]
        var result = Data([type.rawValue])
        let uidData = Data(currentUID.utf8)
        result.append(UInt8(uidData.count))
        result.append(uidData)
        result.append(encrypted)
        return result
    }

    /// Decode an encrypted packet from a known contact.
    func decodeEncryptedPacket(data: Data) -> (type: BLEPacketType, senderUID: String, payload: Data)? {
        guard data.count > 2 else { return nil }

        guard let type = BLEPacketType(rawValue: data[0]) else { return nil }

        let uidLength = Int(data[1])
        guard data.count > 2 + uidLength else { return nil }

        let uidData = data[2..<(2 + uidLength)]
        guard let senderUID = String(data: uidData, encoding: .utf8) else { return nil }

        let encrypted = data[(2 + uidLength)...]

        guard let keyStore = contactKeyStore,
              let sharedKey = keyStore.sharedKey(forContact: senderUID) else {
            print("[BLEDataService] No shared key for \(senderUID), cannot decrypt")
            return nil
        }

        guard let decrypted = try? CryptoService.decrypt(data: Data(encrypted), key: sharedKey) else {
            print("[BLEDataService] Decryption failed for packet from \(senderUID)")
            return nil
        }

        // Extract and verify counter (first 8 bytes)
        guard decrypted.count > 8 else { return nil }
        let counterBytes = decrypted[decrypted.startIndex..<decrypted.startIndex + 8]
        let counter = counterBytes.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        let lastSeen = lastSeenCounter[senderUID] ?? 0

        guard counter > lastSeen else {
            print("[BLEDataService] Replay detected from \(senderUID): counter \(counter) <= \(lastSeen)")
            return nil
        }
        lastSeenCounter[senderUID] = counter

        let payload = decrypted[(decrypted.startIndex + 8)...]
        return (type: type, senderUID: senderUID, payload: Data(payload))
    }

    /// Encode an unencrypted handshake packet (pre-key-exchange).
    func encodeHandshakePacket(type: BLEPacketType, payload: Data) -> Data? {
        let packet = BLEPacket(type: type, senderUID: currentUID, payload: payload)
        return try? JSONEncoder().encode(packet)
    }

    /// Decode an unencrypted handshake packet.
    func decodeHandshakePacket(data: Data) -> BLEPacket? {
        return try? JSONDecoder().decode(BLEPacket.self, from: data)
    }

    // MARK: - Handle incoming data from BLEService

    /// Process an incoming BLE packet (called by BLEService when data is received)
    func handleIncomingPacket(data: Data) {
        // Try encrypted format first (post-handshake packets)
        if let result = decodeEncryptedPacket(data: data) {
            let packet = BLEPacket(type: result.type, senderUID: result.senderUID, payload: result.payload)
            routePacket(packet)
            return
        }

        // Fall back to plaintext JSON for handshake packets
        if let packet = decodeHandshakePacket(data: data) {
            routePacket(packet)
        }
    }

    private func routePacket(_ packet: BLEPacket) {
        switch packet.type {
        case .handshakeRequest:
            handleHandshakeRequest(packet: packet)
        case .handshakeAccept:
            handleHandshakeAccept(packet: packet)
        case .message:
            handleReceivedMessage(packet: packet)
        case .messageAck:
            handleMessageAck(packet: packet)
        case .profileSync, .profileData:
            handleProfileSync(packet: packet)
        }
    }

    // MARK: - Handshake Handling

    private func handleHandshakeRequest(packet: BLEPacket) {
        guard isInHandshakeMode else { return }
        guard let payload = try? JSONDecoder().decode(HandshakePayload.self, from: packet.payload) else {
            return
        }

        guard payload.uid != currentUID else { return }
        guard !(localContactsService?.allConnectionUIDs.contains(payload.uid) ?? false) else { return }

        let peer = DiscoveredPeer(
            id: payload.uid,
            uid: payload.uid,
            firstName: payload.firstName,
            lastName: payload.lastName,
            photoFileName: nil,
            publicKeyData: payload.publicKey,
            broadcastSecretData: payload.broadcastSecret
        )

        if !discoveredHandshakePeers.contains(where: { $0.uid == payload.uid }) {
            discoveredHandshakePeers.append(peer)
            onHandshakePeerDiscovered?(peer)
        }
    }

    private func handleHandshakeAccept(packet: BLEPacket) {
        guard let payload = try? JSONDecoder().decode(HandshakePayload.self, from: packet.payload) else {
            return
        }
        print("[BLEDataService] Handshake accepted from \(payload.firstName) \(payload.lastName)")
    }
}

// MARK: - Error Type

enum BLEDataError: LocalizedError {
    case notConfigured
    case encryptionFailed
    case keyExchangeFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "BLE data service not configured"
        case .encryptionFailed: return "Failed to encrypt BLE packet"
        case .keyExchangeFailed: return "Key exchange failed"
        }
    }
}
