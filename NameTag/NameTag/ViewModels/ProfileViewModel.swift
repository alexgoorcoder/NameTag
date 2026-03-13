import Foundation
import UIKit
import AVFoundation

@Observable
final class ProfileViewModel {
    var firstName = ""
    var lastName = ""
    var selectedImage: UIImage?
    var isEditing = false
    var errorMessage: String?
    var successMessage: String?
    var showingPhotoOptions = false
    var showingCamera = false
    var showingCameraDeniedAlert = false
    var showingResetConfirmation = false

    private var originalFirstName = ""
    private var originalLastName = ""

    var isNameValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasNameChanges: Bool {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines) != originalFirstName ||
        lastName.trimmingCharacters(in: .whitespacesAndNewlines) != originalLastName
    }

    var hasPhotoChange: Bool {
        selectedImage != nil
    }

    var hasChanges: Bool {
        hasNameChanges || hasPhotoChange
    }

    func loadProfile(from appState: AppState) {
        guard let profile = appState.localUserService.currentProfile else { return }
        firstName = profile.firstName
        lastName = profile.lastName
        originalFirstName = profile.firstName
        originalLastName = profile.lastName
        selectedImage = nil
    }

    func startEditing(from appState: AppState) {
        loadProfile(from: appState)
        isEditing = true
        errorMessage = nil
        successMessage = nil
    }

    func requestCameraAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        self.showingCamera = true
                    } else {
                        self.showingCameraDeniedAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showingCameraDeniedAlert = true
        @unknown default:
            showingCameraDeniedAlert = true
        }
    }

    func cancelEditing() {
        firstName = originalFirstName
        lastName = originalLastName
        selectedImage = nil
        isEditing = false
        errorMessage = nil
    }

    func save(using appState: AppState) {
        guard isNameValid else {
            errorMessage = "First and last name are required."
            return
        }

        errorMessage = nil
        successMessage = nil

        do {
            let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

            // Update name if changed
            if hasNameChanges {
                try appState.localUserService.updateProfile(
                    firstName: trimmedFirst,
                    lastName: trimmedLast
                )
            }

            // Save new photo if selected
            if let image = selectedImage {
                let uid = appState.identityService.currentUID
                let filename = try appState.photoStorageService.savePhoto(uid: uid, image: image)
                try appState.localUserService.updatePhotoFileName(filename)
            }

            selectedImage = nil
            isEditing = false
            successMessage = "Profile updated!"

            // Refresh original values
            originalFirstName = trimmedFirst
            originalLastName = trimmedLast
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
