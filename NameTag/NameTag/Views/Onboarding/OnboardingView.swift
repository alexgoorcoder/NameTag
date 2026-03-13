import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var step: OnboardingStep = .name
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedImage: UIImage?
    @State private var isCreating = false
    @State private var errorMessage: String?

    enum OnboardingStep {
        case name
        case photo
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch step {
                case .name:
                    nameStep
                case .photo:
                    photoStep
                }
            }
            .padding()
            .navigationTitle("Welcome to NameTag")
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Step 1: Name

    private var nameStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.text.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("What's your name?")
                .font(.title2.bold())

            VStack(spacing: 12) {
                TextField("First Name", text: $firstName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.givenName)

                TextField("Last Name", text: $lastName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.familyName)
            }
            .padding(.horizontal)

            Spacer()

            Button {
                step = .photo
            } label: {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty ||
                      lastName.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal)
        }
    }

    // MARK: - Step 2: Photo

    private var photoStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Add a profile photo")
                .font(.title2.bold())

            Text("This helps your contacts recognize you")
                .foregroundStyle(.secondary)

            PhotoPickerView(selectedImage: $selectedImage)

            Spacer()

            if isCreating {
                ProgressView("Creating profile...")
            } else {
                VStack(spacing: 12) {
                    Button {
                        createProfile()
                    } label: {
                        Text(selectedImage != nil ? "Done" : "Skip for now")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Back") {
                        step = .name
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Create Profile

    private func createProfile() {
        isCreating = true
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)
        let uid = appState.identityService.currentUID

        do {
            var photoFileName: String?
            if let image = selectedImage {
                photoFileName = try appState.photoStorageService.savePhoto(uid: uid, image: image)
            }

            try appState.localUserService.createProfile(
                uid: uid, firstName: trimmedFirst, lastName: trimmedLast,
                photoFileName: photoFileName
            )

            appState.identityService.isOnboarded = true
            appState.onAppReady()
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
        }
    }
}
