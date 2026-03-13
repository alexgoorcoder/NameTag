import Foundation
import CoreBluetooth

/// Packet types for BLE data exchange
enum BLEPacketType: String, Codable {
    case handshakeRequest
    case handshakeAccept
    case profileData
    case message
    case messageAck
    case profileSync
}

/// Generic BLE packet for data exchange
struct BLEPacket: Codable {
    let type: BLEPacketType
    let senderUID: String
    let payload: Data
}

/// Payload for handshake exchange
struct HandshakePayload: Codable {
    let uid: String
    let firstName: String
    let lastName: String
    let profileVersion: Int
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
    private var currentUID: String = ""

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
        photoStorageService: PhotoStorageService
    ) {
        self.currentUID = currentUID
        self.localContactsService = localContactsService
        self.localMessagingService = localMessagingService
        self.localUserService = localUserService
        self.photoStorageService = photoStorageService
    }

    // MARK: - Handshake Mode

    func enterHandshakeMode() {
        isInHandshakeMode = true
        discoveredHandshakePeers = []
        // In a full implementation, this would start scanning for the handshake
        // characteristic and advertising our own handshake data
    }

    func exitHandshakeMode() {
        isInHandshakeMode = false
        discoveredHandshakePeers = []
    }

    // MARK: - Message Delivery

    /// Attempt to deliver pending messages to a nearby contact.
    /// Called when BLEService detects a known contact in range.
    func deliverPendingMessages(to contactUID: String) {
        guard let messagingService = localMessagingService else { return }

        let pending = messagingService.pendingMessages(for: contactUID)
        guard !pending.isEmpty else { return }

        // In a full implementation, this would:
        // 1. Connect to the contact's peripheral
        // 2. Discover the data exchange service
        // 3. Write each message to the message characteristic
        // 4. Wait for ACKs
        // 5. Mark delivered

        print("[BLEDataService] Would deliver \(pending.count) messages to \(contactUID)")
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

    /// Check if a contact's profile needs syncing and trigger sync if needed
    func syncProfileIfNeeded(for contactUID: String) {
        guard let contactsService = localContactsService,
              let userService = localUserService else { return }

        guard let contact = contactsService.contacts.first(where: { $0.contactUID == contactUID }),
              let myProfile = userService.currentProfile else { return }

        // In a full implementation, this would:
        // 1. Exchange profile versions via BLE
        // 2. If remote version > local lastSyncedProfileVersion, request full profile
        // 3. Update LocalContact with new name/photo

        print("[BLEDataService] Would check profile sync for \(contactUID), local version: \(contact.lastSyncedProfileVersion), my version: \(myProfile.profileVersion)")
    }

    /// Handle receiving a profile sync payload
    func handleProfileSync(packet: BLEPacket) {
        guard let contactsService = localContactsService,
              let photoService = photoStorageService else { return }

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

    // MARK: - Packet Encoding/Decoding

    func encodePacket(type: BLEPacketType, payload: Data) -> Data? {
        let packet = BLEPacket(type: type, senderUID: currentUID, payload: payload)
        return try? JSONEncoder().encode(packet)
    }

    func decodePacket(data: Data) -> BLEPacket? {
        return try? JSONDecoder().decode(BLEPacket.self, from: data)
    }

    // MARK: - Handle incoming data from BLEService

    /// Process an incoming BLE packet (called by BLEService when data is received)
    func handleIncomingPacket(data: Data) {
        guard let packet = decodePacket(data: data) else { return }

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

        // Don't show ourselves or existing contacts
        guard payload.uid != currentUID else { return }
        guard !(localContactsService?.allConnectionUIDs.contains(payload.uid) ?? false) else { return }

        let peer = DiscoveredPeer(
            id: payload.uid,
            uid: payload.uid,
            firstName: payload.firstName,
            lastName: payload.lastName,
            photoFileName: nil
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

        // The other user accepted our handshake — add them as contact
        // This would be triggered after the UI flow confirms the add
        print("[BLEDataService] Handshake accepted from \(payload.firstName) \(payload.lastName)")
    }
}
