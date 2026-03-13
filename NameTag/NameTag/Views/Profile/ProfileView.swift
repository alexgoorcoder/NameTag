import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ProfileViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingPhotoPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let profile = appState.localUserService.currentProfile {
                    Spacer()

                    if viewModel.isEditing {
                        editingContent(profile: profile)
                    } else {
                        displayContent(profile: profile)
                    }

                    Spacer()

                    if !viewModel.isEditing {
                        VStack(spacing: 12) {
                            Button(role: .destructive) {
                                viewModel.showingResetConfirmation = true
                            } label: {
                                Text("Reset Account")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Profile")
            .onAppear { viewModel.loadProfile(from: appState) }
            .alert("Reset Account", isPresented: $viewModel.showingResetConfirmation) {
                Button("Reset", role: .destructive) {
                    appState.resetAccount()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all your data, contacts, and messages. You will need to set up your profile again and re-add contacts. This cannot be undone.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.localUserService.currentProfile != nil {
                        if viewModel.isEditing {
                            Button("Cancel") {
                                viewModel.cancelEditing()
                            }
                        } else {
                            Button("Edit") {
                                viewModel.startEditing(from: appState)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Display Mode

    @ViewBuilder
    private func displayContent(profile: LocalProfile) -> some View {
        AsyncProfileImage(photoFileName: profile.photoFileName)
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(Circle().stroke(.separator, lineWidth: 1))

        VStack(spacing: 4) {
            Text(profile.fullName)
                .font(.title2.bold())
        }

        if let message = viewModel.successMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.green)
                .transition(.opacity)
        }
    }

    // MARK: - Editing Mode

    @ViewBuilder
    private func editingContent(profile: LocalProfile) -> some View {
        // Tappable profile photo with camera badge
        profilePhotoEditor(currentPhotoFileName: profile.photoFileName)

        // Name fields
        VStack(spacing: 12) {
            TextField("First Name", text: $viewModel.firstName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.givenName)
                .autocorrectionDisabled()

            TextField("Last Name", text: $viewModel.lastName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.familyName)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 32)

        // Error message
        if let error = viewModel.errorMessage {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }

        // Save button
        Button {
            viewModel.save(using: appState)
        } label: {
            Text("Save Changes")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!viewModel.hasChanges || !viewModel.isNameValid)
        .padding(.horizontal, 32)
    }

    // MARK: - Profile Photo Editor

    @ViewBuilder
    private func profilePhotoEditor(currentPhotoFileName: String?) -> some View {
        VStack(spacing: 12) {
            // Single photo circle — shows new selection or current photo
            ZStack(alignment: .bottomTrailing) {
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.secondary, lineWidth: 2))
                } else {
                    AsyncProfileImage(photoFileName: currentPhotoFileName)
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.secondary, lineWidth: 2))
                }

                // Camera badge
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white, .blue)
                    .offset(x: -4, y: -4)
            }
            .onTapGesture {
                viewModel.showingPhotoOptions = true
            }

            Text("Tap photo to change")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Show remove button if a new image was selected
            if viewModel.selectedImage != nil {
                Button("Remove New Selection", role: .destructive) {
                    viewModel.selectedImage = nil
                }
                .font(.caption)
            }
        }
        .confirmationDialog("Change Profile Photo", isPresented: $viewModel.showingPhotoOptions) {
            Button("Choose from Library") {
                showingPhotoPicker = true
            }
            Button("Take Photo") {
                viewModel.requestCameraAccess()
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, newItem in
            Task {
                guard let newItem else { return }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    viewModel.selectedImage = uiImage
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $viewModel.showingCamera) {
            CameraView(image: $viewModel.selectedImage)
                .ignoresSafeArea()
        }
        .alert("Camera Access Required", isPresented: $viewModel.showingCameraDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Camera access was previously denied. Please enable it in Settings to take a photo.")
        }
    }
}
