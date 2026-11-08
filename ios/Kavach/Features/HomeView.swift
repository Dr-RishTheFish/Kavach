import SwiftUI

struct HomeView: View {
    let openAnalyze: () -> Void

    var body: some View {
        Screen {
            ContentCard {
                Label("YOUR SAFETY COMPANION", systemImage: "shield.lefthalf.filled")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                Text("A little pause.\nA clearer next step.")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("When a call or message feels off, take a breath and check before you act.")
                    .foregroundStyle(.secondary)
                ActionButton(title: "Explore a sample", symbol: "arrow.up.right", action: openAnalyze)
                Label("Offline demo · No monitoring is active", systemImage: "iphone")
                    .font(.caption).foregroundStyle(.secondary)
            }
            SectionHeading(title: "A closer look", subtitle: "Featured sample assessment")
            if let assessment = try? DemoScenario.bank.assessment() {
                RiskScoreCard(assessment: assessment)
            }
            SectionHeading(title: "Good habits, right now", subtitle: "Small actions that keep you in control")
            ContentCard {
                Label("Keep one-time codes to yourself", systemImage: "key")
                Divider()
                Label("Verify through a number you trust", systemImage: "phone.arrow.up.right")
                Divider()
                Label("Pause when someone pressures you", systemImage: "pause.circle")
            }
            SectionHeading(title: "Coming to kavach", subtitle: "These features are not connected yet")
            ContentCard {
                Label("AI-assisted analysis", systemImage: "sparkles")
                Text("Live analysis will arrive after backend integration.").font(.subheadline).foregroundStyle(.secondary)
                Divider()
                Label("Your trusted circle", systemImage: "person.2")
                Text("Share a redacted summary only when you choose.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("kavach")
    }
}
