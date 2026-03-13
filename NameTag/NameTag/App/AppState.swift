import Foundation
import SwiftData
import CryptoKit

@Observable
final class AppState {
    let keychainService: KeychainService
    let contactKeyStore: ContactKeyStore
    let identityService: IdentityService
    let localUserService: LocalUserService
    let localContactsService: LocalContactsService
    let localMessagingService: LocalMessagingService
    let photoStorageService: PhotoStorageService
    let bleService: BLEService
    let bleDataService: BLEDataService
    let notificationGatekeeper: NotificationGatekeeper

    private let deviceKey: SymmetricKey

    private static let deviceKeyKeychainKey = "device.encryptionKey"

    var hasCompletedOnboarding: Bool {
        identityService.isOnboarded && localUserService.currentProfile != nil
    }

    init(modelContext: ModelContext) {
        let kc = KeychainService()
        keychainService = kc
        contactKeyStore = ContactKeyStore(keychainService: kc)
        identityService = IdentityService(keychainService: kc)
        localUserService = LocalUserService(modelContext: modelContext)
        localContactsService = LocalContactsService(modelContext: modelContext)
        localMessagingService = LocalMessagingService(modelContext: modelContext, currentUID: identityService.currentUID)
        photoStorageService = PhotoStorageService()
        bleService = BLEService()
        bleDataService = BLEDataService()
        notificationGatekeeper = NotificationGatekeeper()

        // Load or generate device encryption key
        if let keyData = kc.load(key: Self.deviceKeyKeychainKey) {
            deviceKey = CryptoService.deserializeSymmetricKey(keyData)
        } else {
            let key = CryptoService.generateDeviceEncryptionKey()
            try? kc.save(key: Self.deviceKeyKeychainKey, data: CryptoService.serializeSymmetricKey(key))
            deviceKey = key
        }

        // Configure encryption for data-at-rest services
        localMessagingService.configureEncryption(deviceKey: deviceKey)
        photoStorageService.configureEncryption(deviceKey: deviceKey)
    }

    func onAppReady() {
        guard identityService.isOnboarded else { return }
        localUserService.loadProfile(uid: identityService.currentUID)
        guard localUserService.currentProfile != nil else { return }

        let connectionUIDs = localContactsService.connectionUIDs
        bleService.configure(userID: identityService.currentUID, connectionUIDs: connectionUIDs)
        bleService.configureCrypto(
            broadcastSecret: identityService.broadcastSecret,
            contactKeyStore: contactKeyStore
        )
        bleService.startDiscovery()

        // Configure data exchange service with crypto
        bleDataService.configure(
            currentUID: identityService.currentUID,
            localContactsService: localContactsService,
            localMessagingService: localMessagingService,
            localUserService: localUserService,
            photoStorageService: photoStorageService,
            contactKeyStore: contactKeyStore,
            identityKeyPair: identityService.identityKeyPair,
            publicKeyData: identityService.publicKeyData,
            broadcastSecret: identityService.broadcastSecret
        )

        // Wire notification callbacks and message delivery
        let gatekeeper = notificationGatekeeper
        let dataService = bleDataService
        bleService.onContactDiscovered = { uid in
            gatekeeper.notifyIfAllowed(uid: uid)
            dataService.deliverPendingMessages(to: uid)
            dataService.syncProfileIfNeeded(for: uid)
        }

        // Populate notification gatekeeper names
        let names = Dictionary(uniqueKeysWithValues:
            localContactsService.contacts.map { ($0.contactUID, $0.fullName) })
        notificationGatekeeper.connectionNames = names
    }

    /// Re-check all currently nearby contacts through the notification gatekeeper.
    func recheckNearbyNotifications() {
        let allNearbyUIDs = Set(bleService.nearbyUserIDs.keys)
        guard !allNearbyUIDs.isEmpty else { return }

        for uid in allNearbyUIDs {
            notificationGatekeeper.notifyIfAllowed(uid: uid)
        }
    }

    /// Restart BLE scanning when returning to foreground
    func resumeForegroundServices() {
        guard identityService.isOnboarded else { return }
        bleService.startScanning()
    }

    /// Reset all data and identity (account deletion equivalent)
    func resetAccount() {
        bleService.stopAll()
        bleService.clearPersistedConfig()
        contactKeyStore.deleteAll()
        notificationGatekeeper.reset()
        try? localMessagingService.deleteAllData()
        try? localContactsService.deleteAllContacts()
        try? localUserService.deleteProfile()
        photoStorageService.deleteAllPhotos()
        keychainService.delete(key: Self.deviceKeyKeychainKey)
        identityService.resetIdentity()
    }
}
