import SwiftUI

struct SettingsView: View {
    @AppStorage("developmentAPIBaseURL") private var savedURL = ""
    @State private var draftURL = ""
    @State private var validationMessage: String?

    var body: some View {
        Form {
            Section("Current experience") {
                Label("Demo Mode · On", systemImage: "sparkles")
                Text("All assessments use local, fictional fixtures. NVIDIA, Photon and circle services are not connected.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                TextField("https://your-development-server", text: $draftURL)
                    .textContentType(.URL).keyboardType(.URL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityLabel("Development API base URL")
                Button("Save development address") { saveAddress() }
                if let validationMessage { Text(validationMessage).font(.caption) }
                Text("Saving an address does not enable HTTP mode or send a request. On an iPhone, localhost refers to the phone, not your Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text("Development server") }
            Section("Your privacy") {
                Label("Sharing is off", systemImage: "hand.raised")
                Text("This demo does not read your messages, listen to calls, monitor contacts, or save reports.")
                Text("Only the development server address is stored on this device. No assessment text is logged or retained.")
            }
            Section("What comes next") {
                LabeledContent("Live AI analysis", value: "Later")
                LabeledContent("Saved reports", value: "Later")
                LabeledContent("Circle invitations", value: "Later")
                LabeledContent("iMessage companion", value: "Later")
            }
            Section {
                Text("Risk scores are heuristic assessments. They do not prove fraud or guarantee safety.")
            }
        }
        .navigationTitle("Settings")
        .onAppear { draftURL = savedURL }
    }

    private func saveAddress() {
        let value = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            savedURL = ""
            validationMessage = "Development address cleared. Demo Mode remains on."
            return
        }
        guard let url = URL(string: value), (try? HTTPAnalysisService(baseURL: url)) != nil else {
            validationMessage = AnalysisServiceError.invalidBaseURL.localizedDescription
            return
        }
        savedURL = value
        validationMessage = "Address saved. Demo Mode remains on."
    }
}
