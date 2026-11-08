import SwiftUI

struct CircleView: View {
    var body: some View {
        Screen {
            ContentCard {
                Image(systemName: "person.2.circle").font(.system(size: 64)).foregroundStyle(Theme.accent).accessibilityHidden(true)
                Text("Looking out for\neach other.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("A private space for the people you trust. Share a little context when you want a second pair of eyes.").foregroundStyle(.secondary)
                Label("PREVIEW · No circle is connected", systemImage: "eye").font(.caption.bold())
            }
            SectionHeading(title: "Your people, by invitation", subtitle: "Illustrative members only")
            ForEach(["You", "Family member", "Trusted friend"], id: \.self) { member in
                ContentCard {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill").font(.largeTitle).foregroundStyle(Theme.accent).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member).font(.headline)
                            Text("Demo member").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            EmptyState(title: "No shared alerts", message: "Invitations and alerts are coming later. This preview does not create accounts, invite anyone, or share information.", symbol: "tray")
            ContentCard {
                Label("Sharing starts with your choice", systemImage: "hand.raised")
                    .font(.headline)
                Text("Future sharing will ask for explicit confirmation and use a redacted summary. Sharing is off by default.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Circle")
    }
}
