import CoreBluetooth

enum BLE {
    // Proximity detection (existing)
    static let serviceUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
    static let characteristicUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567891")
    static let staleTimeout: TimeInterval = 30

    // Data exchange service
    static let dataServiceUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567892")
    static let profileCharacteristicUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567893")
    static let messageCharacteristicUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567894")
    static let handshakeCharacteristicUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567895")

    // State restoration identifiers
    static let centralRestoreIdentifier = "com.nametag.central"
    static let peripheralRestoreIdentifier = "com.nametag.peripheral"

    // BLE transfer limits
    static let maxGATTPayload = 512
    static let photoChunkSize = 480

    // Rotating identifier window (seconds)
    static let rotationWindowSeconds = 900
}

enum Proximity {
    static let mergedStaleTimeout: TimeInterval = 60
}

enum NotificationSuppression {
    static let userDefaultsKey = "notificationSuppressionDuration"
    static let defaultDuration: TimeInterval = 900

    static let none: TimeInterval = 0
    static let fifteenMinutes: TimeInterval = 900
    static let oneHour: TimeInterval = 3600
    static let oneDay: TimeInterval = 86400
}
