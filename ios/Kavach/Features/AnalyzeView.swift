import SwiftUI

struct AnalyzeView: View {
    @State private var kind: AnalysisKind = .call
    @State private var scenario: DemoScenario = .bank
    @State private var assessment: RiskAssessment?
    @State private var isLoading = false
    @State private var failed = false
    private let service: any AnalysisService = MockAnalysisService()

    private var scenarios: [DemoScenario] { DemoScenario.allCases.filter { $0.request.kind == kind } }

    var body: some View {
        Screen {
            SectionHeading(title: "Make room for a second look", subtitle: "Explore fictional examples. Nothing is sent to a server.")
            ContentCard {
                Picker("Sample category", selection: $kind) {
                    ForEach(AnalysisKind.allCases) { kind in Label(kind.title, systemImage: kind.symbol).tag(kind) }
                }
                .pickerStyle(.menu)
                Picker("Demo scenario", selection: $scenario) {
                    ForEach(scenarios) { Text($0.title).tag($0) }
                }
                Text(scenario.request.content).font(.body).foregroundStyle(.secondary)
                Text("Fictional sample · No personal messages accessed").font(.caption).foregroundStyle(.secondary)
            }
            if isLoading {
                ContentCard { ProgressView("Loading a local sample…").frame(maxWidth: .infinity) }
            } else if failed {
                EmptyState(title: "Sample unavailable", message: "Try another sample. No information was sent.", symbol: "exclamationmark.circle")
            } else if let assessment {
                RiskScoreCard(assessment: assessment)
                ContentCard {
                    Text("What stands out").font(.headline)
                    if assessment.signals.isEmpty {
                        Text("No warning signals are listed in this fixture. That does not establish safety.").foregroundStyle(.secondary)
                    }
                    ForEach(assessment.signals, id: \.self) { Label($0, systemImage: "magnifyingglass") }
                }
                ContentCard {
                    Text("A safer next step").font(.headline)
                    ForEach(assessment.recommendedActions, id: \.self) { Label($0, systemImage: "arrow.turn.down.right") }
                }
            }
            Text("Live analysis and your own message submissions are coming in a later module.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Analyze")
        .onChange(of: kind) { _, newKind in
            scenario = DemoScenario.allCases.first { $0.request.kind == newKind } ?? .bank
        }
        .task(id: scenario) { await loadSample() }
    }

    @MainActor
    private func loadSample() async {
        isLoading = true
        failed = false
        do {
            let value = try await service.analyze(scenario.request)
            try Task.checkCancellation()
            assessment = value
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            failed = true
            isLoading = false
        }
    }
}

#Preview { NavigationStack { AnalyzeView() } }
