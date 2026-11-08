import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var draftURL = ""
    @State private var validationMessage: String?

    var body: some View {
        Form {
            Section("Accounts, reports and circles") {
                NavigationLink("Explore the final UI demo") { FinalWorkspaceView() }
                Text("Demo accounts and reports stay in memory. Connected accounts, push alerts and Messages require backend provisioning.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Analysis service") {
                Picker("Service", selection: $settings.configuration.mode) {
                    ForEach(AnalysisMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }.accessibilityIdentifier("serviceMode")
                Text(settings.configuration.mode == .mock
                     ? "Demo Mode · On"
                     : "Live backend selected. The result's source confirms whether NVIDIA was used.")
                Text("Changing mode never submits your text. The app sends a request only when you tap Analyze.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Development server") {
                TextField("https://your-development-server", text: $draftURL)
                    .textContentType(.URL).keyboardType(.URL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityLabel("Development API base URL")
                Button("Save development address") { saveAddress() }
                if let validationMessage { Text(validationMessage).font(.caption) }
                if settings.configuration.mode == .live && settings.configuration.baseURL.isEmpty {
                    Text("Add your backend address to use Live backend. There is no automatic mock fallback.").font(.subheadline)
                }
                Text("On an iPhone, localhost means the phone. Use your backend Mac's LAN address. HTTP is unencrypted: use synthetic test text only. Prefer HTTPS.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("An address does not prove server or NVIDIA availability. No connection check runs automatically.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Your privacy") {
                Label("Sharing is off", systemImage: "hand.raised")
                Text("Kavach does not read your messages, listen to calls, monitor contacts, or save reports.")
                Text("Only service mode and server address are stored here. Entered content and assessments remain in this app session. Live submissions are processed by the configured backend.")
            }
            Section("Coming later") {
                LabeledContent("Saved reports", value: "Later")
                LabeledContent("Circle invitations", value: "Later")
                LabeledContent("iMessage companion", value: "Later")
            }
            Section { Text("Risk scores are heuristic assessments. They do not prove fraud or guarantee safety.") }
        }
        .navigationTitle("Settings")
        .onAppear { draftURL = settings.configuration.baseURL }
    }

    private func saveAddress() {
        let value = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            guard let url = URL(string: value), (try? HTTPAnalysisService(baseURL: url)) != nil else {
                validationMessage = AnalysisServiceError.invalidBaseURL.localizedDescription
                return
            }
        }
        settings.configuration.baseURL = value
        validationMessage = value.isEmpty ? "Address cleared." : "Address saved. No request was sent."
    }
}
