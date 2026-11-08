import SwiftUI

enum Theme {
    static let accent = Color.teal
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
}

extension RiskLevel {
    var color: Color {
        switch self {
        case .low: return .green
        case .guarded: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    var symbol: String {
        switch self {
        case .low: return "leaf"
        case .guarded: return "eye"
        case .high: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.shield"
        }
    }
}

struct ContentCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct Screen<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { content }
                .frame(maxWidth: 640).padding(20).frame(maxWidth: .infinity)
        }
        .background(Theme.background)
    }
}

struct SectionHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title2.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

struct DemoBanner: View {
    var body: some View {
        Label("DEMO · Simulated assessment", systemImage: "sparkles")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityIdentifier("demoBanner")
    }
}

struct RiskBadge: View {
    let level: RiskLevel
    var body: some View {
        Label(level.title, systemImage: level.symbol)
            .font(.subheadline.bold()).foregroundStyle(.primary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(level.color.opacity(0.2), in: Capsule())
    }
}

struct RiskScoreCard: View {
    let assessment: RiskAssessment
    var body: some View {
        ContentCard {
            if assessment.source == .mock { DemoBanner() }
            else { Label(assessment.source.displayTitle, systemImage: "sparkles").font(.headline) }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) { score; Spacer(); RiskBadge(level: assessment.riskLevel) }
                VStack(alignment: .leading, spacing: 12) { score; RiskBadge(level: assessment.riskLevel) }
            }
            Text(assessment.summary).font(.headline).fixedSize(horizontal: false, vertical: true)
            Text("A heuristic risk score, not a fraud probability or a guarantee of safety.")
                .font(.caption).foregroundStyle(.secondary)
            if assessment.requiresHumanReview {
                Label("Additional verification recommended", systemImage: "person.crop.circle.badge.questionmark")
                    .font(.subheadline)
            }
        }
    }

    private var score: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(assessment.riskScore)").font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("/ 100").foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Risk score \(assessment.riskScore) out of 100, \(assessment.riskLevel.title)")
    }
}

struct ActionButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.headline)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent).controlSize(.large)
    }
}

struct EmptyState: View {
    let title: String
    let message: String
    let symbol: String
    var body: some View {
        ContentCard {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(Theme.accent).accessibilityHidden(true)
            Text(title).font(.headline)
            Text(message).foregroundStyle(.secondary)
        }
    }
}
