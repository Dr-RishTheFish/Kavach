import SwiftUI

struct AnalyzeView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var model = AnalysisViewModel()
    @State private var submission: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    var body: some View {
        Screen {
            SectionHeading(title: "Take a moment to check", subtitle: "Describe what happened. You decide what to share.")
            ContentCard {
                Label(settings.configuration.mode.title, systemImage: settings.configuration.mode == .mock ? "sparkles" : "network")
                    .font(.headline)
                Text(settings.configuration.mode == .mock
                     ? "Offline demo. Results are simulated; your text stays on this device."
                     : "When you tap Analyze, your entered text is sent to your configured server for AI evaluation. Its response identifies whether AI was actually used.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if settings.configuration.mode == .live && settings.configuration.baseURL.lowercased().hasPrefix("http://") {
                    Text("This server uses unencrypted HTTP. Use synthetic test text only.").font(.footnote).foregroundStyle(.orange)
                }
                Text("Change offline/live service in Settings.").font(.caption).foregroundStyle(.secondary)
            }
            ContentCard {
                Text("1. Choose the kind of contact").font(.headline)
                Picker("Contact type", selection: $model.draft.kind) {
                    ForEach(AnalysisKind.allCases) { kind in Text(kind.formTitle).tag(kind) }
                }.pickerStyle(.menu).accessibilityIdentifier("analysisKind")
                Text("2. Describe what happened").font(.headline)
                Text(model.draft.kind.inputPrompt).font(.subheadline).foregroundStyle(.secondary)
                TextEditor(text: $model.draft.content)
                    .frame(minHeight: 130).focused($inputFocused)
                    .accessibilityLabel("Suspicious content").accessibilityIdentifier("analysisContent")
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                Text("\(model.draft.contentCount) / 5,000 characters")
                    .font(.caption).foregroundStyle(model.draft.contentCount > 5000 ? Color.red : Color.secondary)
                if model.draft.supportsPhone {
                    TextField("Phone number (optional, +country code)", text: $model.draft.phoneNumber)
                        .keyboardType(.phonePad).textContentType(.telephoneNumber)
                        .accessibilityIdentifier("analysisPhone")
                }
                TextField("Additional context (optional)", text: $model.draft.context, axis: .vertical)
                    .lineLimit(2...5).accessibilityIdentifier("analysisContext")
                Text("\(model.draft.contextCount) / 1,000 context characters")
                    .font(.caption).foregroundStyle(.secondary)
                if let message = model.draft.validationMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Menu("Use a fictional example") {
                    ForEach(DemoScenario.allCases) { scenario in
                        Button(scenario.title) {
                            model.draft = .init(kind: scenario.request.kind, content: scenario.request.content)
                        }
                    }
                }.accessibilityIdentifier("sampleMenu")
            }
            ContentCard {
                Text("3. Review and analyze").font(.headline)
                Text("Only submit information you choose to share. Remove private codes, passwords and account details first.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if model.isBusy {
                    ProgressView("Analyzing…")
                    Button("Cancel analysis") { cancel() }.accessibilityIdentifier("cancelAnalysis")
                } else {
                    ActionButton(title: settings.configuration.mode == .mock ? "Analyze demo" : "Analyze", symbol: "magnifyingglass") {
                        inputFocused = false
                        submission = Task { await model.submit(configuration: settings.configuration) }
                    }.disabled(!model.canSubmit).accessibilityIdentifier("submitAnalysis")
                }
            }
            switch model.state {
            case .success(let assessment):
                AnalysisResultView(assessment: assessment, requestedMode: model.submittedMode)
            case .failure(let error):
                EmptyState(title: "Analysis unavailable", message: error.message, symbol: "exclamationmark.circle")
                    .accessibilityIdentifier("analysisError")
                Text("Your input is still here. Check it and tap Analyze to retry.").font(.footnote).foregroundStyle(.secondary)
            case .idle:
                Text("Results appear here after you tap Analyze. Nothing is saved as a report.").font(.footnote).foregroundStyle(.secondary)
            case .validating, .loading: EmptyView()
            }
        }
        .navigationTitle("Analyze")
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: settings.configuration) { _, _ in cancel() }
        .onDisappear { cancel() }
    }
    private func cancel() { submission?.cancel(); submission = nil; model.cancel() }
}

struct AnalysisResultView: View {
    let assessment: RiskAssessment
    let requestedMode: AnalysisMode
    var body: some View {
        RiskScoreCard(assessment: assessment)
        NavigationLink("Save a demo private report") { SaveDemoReportView(assessment: assessment) }
        Text("The report demo is stored only in this app session. It does not save to the backend.")
            .font(.caption).foregroundStyle(.secondary)
        if requestedMode == .live && assessment.source == .mock {
            Text("Your backend returned a simulated assessment. This is not live NVIDIA analysis.")
                .font(.headline).accessibilityIdentifier("liveReturnedMock")
        }
        ContentCard {
            Text("What stands out").font(.headline)
            if assessment.signals.isEmpty {
                Text("No warning signals were listed. That does not establish safety.").foregroundStyle(.secondary)
            }
            ForEach(Array(assessment.signals.enumerated()), id: \.offset) { _, signal in Label(signal, systemImage: "magnifyingglass") }
        }
        ContentCard {
            Text("A safer next step").font(.headline)
            ForEach(Array(assessment.recommendedActions.enumerated()), id: \.offset) { _, action in Label(action, systemImage: "arrow.turn.down.right") }
            Text(assessment.analyzedAt, format: .dateTime.year().month().day().hour().minute())
                .font(.caption).foregroundStyle(.secondary)
            Text("Session-only assessment · Not a saved report").font(.caption).foregroundStyle(.secondary)
        }
    }
}

extension AnalysisKind {
    var formTitle: String {
        switch self {
        case .call: return "Suspicious Call"
        case .sms: return "Text/SMS"
        case .message: return "Other Message"
        case .url: return "Suspicious Link"
        }
    }
    var inputPrompt: String {
        switch self {
        case .call: return "What did the caller say or ask you to do?"
        case .sms: return "Type or paste the suspicious SMS text."
        case .message: return "Type or paste the message you want to check."
        case .url: return "Paste the link as text. Kavach will not open or preview it."
        }
    }
}

#Preview { NavigationStack { AnalyzeView() }.environmentObject(AppSettings(defaults: UserDefaults(suiteName: "kavach-preview")!)) }
#Preview("Risk bands") {
    Screen {
        ForEach([DemoScenario.lunch, .unknownContact, .delivery, .bank]) { scenario in
            if let assessment = try? scenario.assessment() { AnalysisResultView(assessment: assessment, requestedMode: .mock) }
        }
    }
}
#Preview("Loading and error") {
    Screen {
        ContentCard { ProgressView("Analyzing…"); Button("Cancel analysis") {} }
        EmptyState(title: "Analysis unavailable", message: "The request timed out. Check the server and try again.", symbol: "exclamationmark.circle")
    }
}
