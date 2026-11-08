import SwiftUI

struct FinalWorkspaceView: View {
    @EnvironmentObject private var store: FinalDemoStore
    @State private var circleName = ""
    @State private var inviteCode = ""
    @State private var error: String?
    var body: some View {
        List {
            Section {
                Label("DEMO · Final UI preview", systemImage: "sparkles").font(.headline)
                Text("Fictional accounts and in-memory data on this device. Nothing here authenticates, persists to the server, sends a push, or contacts Messages.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Demo account") {
                if let account = store.account {
                    LabeledContent("Fictional identity", value: account.rawValue)
                    Button("Sign out of demo") { store.signOut() }
                } else {
                    Text("Choose an identity to explore privacy and membership flows. This is not Sign in with Apple or a backend test account.")
                }
                ForEach(DemoAccount.allCases) { account in
                    Button("Enter demo as \(account.rawValue)") { store.enterDemoAccount(account) }
                }
            }
            if store.account != nil {
                Section("Private demo reports") {
                    NavigationLink("My demo reports (\(store.reports.count))") { DemoReportsView() }
                    Text("Analyze a fictional example, then choose Save demo report on its result. Original text is excluded by default.").font(.caption)
                }
                Section("Your demo circles") {
                    if store.circles.isEmpty { Text("No demo circles yet.").foregroundStyle(.secondary) }
                    ForEach(store.circles) { circle in
                        NavigationLink(circle.name) { DemoCircleDetailView(circleID: circle.id) }
                    }
                    TextField("Circle name", text: $circleName)
                    Button("Create demo circle") { act { _ = try store.createCircle(name: circleName); circleName = "" } }
                        .disabled(circleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Join by invitation") {
                    TextField("DEMO invitation code", text: $inviteCode).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Button("Join demo circle") { act { try store.join(code: inviteCode); inviteCode = "" } }.disabled(inviteCode.isEmpty)
                    Text("Create an invite as Asha, switch to Ravi, and redeem it here. The demo invite expires after 15 minutes and is single-use.").font(.caption)
                }
            }
            Section("Real service status") {
                Label("Account service: not connected", systemImage: "person.crop.circle.badge.questionmark")
                Label("Push: not registered", systemImage: "bell.slash")
                Label("Live circle feed: not connected", systemImage: "network.slash")
                NavigationLink("Messages agent setup") { DemoAgentStatusView() }
                Text("Real services require Person 2's final APIs, your Apple capabilities, and a verified managed line. Demo data is never silently sent to them.").font(.caption)
            }
            Section {
                Button("Clear all demo data", role: .destructive) { store.clearDemoData() }
            }
        }
        .navigationTitle("Demo workspace")
        .alert("Demo action unavailable", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }
    private func act(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}

struct SaveDemoReportView: View {
    let assessment: RiskAssessment
    @EnvironmentObject private var store: FinalDemoStore
    @State private var showSave = false
    var body: some View {
        ContentCard {
            Text("Keep a private demo report").font(.headline)
            Text("DEMO · Memory only. This does not save to your backend or share with a circle.").font(.caption).foregroundStyle(.secondary)
            if store.account == nil {
                NavigationLink("Choose a demo account") { FinalWorkspaceView() }
            } else {
                Button("Save demo report") { showSave = true }
            }
        }
        .sheet(isPresented: $showSave) {
            NavigationStack { DemoSaveSheet(assessment: assessment).environmentObject(store) }
        }
    }
}

private struct DemoSaveSheet: View {
    let assessment: RiskAssessment
    @EnvironmentObject private var store: FinalDemoStore
    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var notes = ""
    @State private var consent = false
    @State private var operation = UUID()
    @State private var error: String?
    var body: some View {
        Form {
            Section {
                Text("DEMO · Private, session-only report").font(.headline)
                Text("No original message is included. Enter only fictional details you choose to keep. Saving does not share anything.")
            }
            Section("Optional private details") {
                TextField("Description (optional)", text: $description, axis: .vertical)
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                Text("Description: \(description.unicodeScalars.count)/5000 · Notes: \(notes.unicodeScalars.count)/1000").font(.caption)
            }
            Section {
                Toggle("I choose to keep this private demo report in this app session", isOn: $consent)
                Button("Confirm private demo save") {
                    do {
                        _ = try store.save(assessment: assessment, description: description, notes: notes, consent: consent, operation: operation)
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }.disabled(!consent || description.unicodeScalars.count > 5000 || notes.unicodeScalars.count > 1000)
                if let error { Text(error).foregroundStyle(.red) }
            }
        }.navigationTitle("Save demo report")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onChange(of: store.account) { _, _ in dismiss() }
    }
}

private struct DemoReportsView: View {
    @EnvironmentObject private var store: FinalDemoStore
    var body: some View {
        List {
            Section { Text("DEMO · Private to the selected fictional account. Reports disappear when this app session ends.").font(.caption) }
            if store.reports.isEmpty { Text("No private demo reports. Analyze a fictional example first.") }
            ForEach(store.reports) { report in
                NavigationLink { DemoReportDetailView(reportID: report.id) } label: {
                    VStack(alignment: .leading) {
                        Text(report.assessment.summary).lineLimit(2)
                        Text("\(report.assessment.kind.title) · \(report.assessment.riskLevel.title)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.navigationTitle("My demo reports")
    }
}

private struct DemoReportDetailView: View {
    let reportID: UUID
    @EnvironmentObject private var store: FinalDemoStore
    @Environment(\.dismiss) private var dismiss
    @State private var delete = false
    @State private var sharing = false
    @State private var error: String?
    var body: some View {
        Screen {
            if let report = store.reports.first(where: { $0.id == reportID }) {
                Text("DEMO · Private session-only report").font(.headline)
                RiskScoreCard(assessment: report.assessment)
                ContentCard {
                    Text("Private details").font(.headline)
                    Text(report.description ?? "Original description was not included.")
                    if let notes = report.notes { Text(notes) }
                    Text(report.createdAt, style: .date).font(.caption)
                }
                Button("Review sharing preview") { sharing = true }.disabled(store.circles.isEmpty)
                if store.circles.isEmpty { Text("Create or join a demo circle before sharing.").font(.caption) }
                Button("Delete private demo report", role: .destructive) { delete = true }
            } else { Text("This report is not available to the current demo account.") }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Demo report")
            .confirmationDialog("Delete this private demo report? Shared demo alerts will also be removed.", isPresented: $delete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { do { try store.deleteReport(reportID); dismiss() } catch { self.error = error.localizedDescription } }
            }
            .sheet(isPresented: $sharing) { NavigationStack { DemoShareSheet(reportID: reportID).environmentObject(store) } }
    }
}

private struct DemoShareSheet: View {
    let reportID: UUID
    @EnvironmentObject private var store: FinalDemoStore
    @Environment(\.dismiss) private var dismiss
    @State private var circleID: UUID?
    @State private var preview = ""
    @State private var consent = false
    @State private var operation = UUID()
    @State private var error: String?
    var body: some View {
        Form {
            Section {
                Text("DEMO · Separate sharing confirmation").font(.headline)
                Text("Members see exactly this preview, risk level and time. Private description and notes are excluded. A user report is not proof of fraud.")
            }
            Section("Choose a circle") {
                Picker("Demo circle", selection: $circleID) {
                    Text("Choose a circle").tag(UUID?.none)
                    ForEach(store.circles) { Text($0.name).tag(Optional($0.id)) }
                }
            }
            Section("Exact preview members will see") {
                TextEditor(text: $preview).frame(minHeight: 100)
                Text("\(preview.unicodeScalars.count)/140 characters").font(.caption)
                Text("Remove names, numbers, codes and private details. Previously delivered notifications or screenshots cannot be recalled.").font(.caption)
                Toggle("I approve sharing this exact preview to the selected demo circle", isOn: $consent)
                Button("Confirm demo share") {
                    guard let circleID else { return }
                    do { try store.share(report: reportID, circle: circleID, preview: preview, consent: consent, operation: operation); dismiss() }
                    catch { self.error = error.localizedDescription }
                }.disabled(!consent || circleID == nil || preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || preview.unicodeScalars.count > 140)
                if let error { Text(error).foregroundStyle(.red) }
            }
        }.navigationTitle("Review demo share")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { preview = String((store.reports.first { $0.id == reportID }?.assessment.summary ?? "").prefix(140)) }
            .onChange(of: store.account) { _, _ in dismiss() }
    }
}

private struct DemoCircleDetailView: View {
    let circleID: UUID
    @EnvironmentObject private var store: FinalDemoStore
    @Environment(\.dismiss) private var dismiss
    @State private var invitation: DemoInvite?
    @State private var leave = false
    @State private var error: String?
    var body: some View {
        List {
            if let circle = store.circles.first(where: { $0.id == circleID }) {
                Section {
                    Text(circle.name).font(.title2)
                    Text("DEMO · Invite-only, memory-only circle").font(.caption)
                    Text("Feed is local demo state; no SSE connection or remote push is active.").font(.caption)
                }
                Section("Members") {
                    ForEach(circle.members.sorted(by: { $0.rawValue < $1.rawValue })) { member in
                        HStack {
                            Text(member.rawValue)
                            Spacer()
                            Text(member == circle.owner ? "Owner" : "Member").font(.caption)
                            if circle.owner == store.account && member != store.account {
                                Button("Remove", role: .destructive) { act { try store.remove(member, from: circleID) } }
                            }
                        }
                    }
                }
                if circle.owner == store.account {
                    Section("Single-use invitation") {
                        Button("Generate demo invite") { act { invitation = try store.invite(to: circleID) } }
                        if let invitation {
                            Text(invitation.code).textSelection(.enabled).font(.headline.monospaced())
                            Text("Expires \(invitation.expiresAt.formatted(date: .omitted, time: .shortened))").font(.caption)
                            ShareLink("Share demo invitation", item: invitation.code)
                            Text("For these two fictional accounts on this device only. Never use a demo code as a real invitation.").font(.caption)
                        }
                    }
                }
                Section("Shared preview feed") {
                    if store.alerts(in: circleID).isEmpty { Text("No shared demo alerts.") }
                    ForEach(store.alerts(in: circleID)) { alert in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(alert.preview)
                            RiskBadge(level: alert.level)
                            Text(alert.createdAt, style: .time).font(.caption)
                            Text("DEMO · User-submitted preview").font(.caption)
                        }
                    }
                }
                Section { Button("Leave demo circle", role: .destructive) { leave = true } }
            } else { Text("Circle unavailable to the selected demo account.") }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Demo circle")
            .confirmationDialog("Leave this demo circle? An owner with other members must remove them first.", isPresented: $leave, titleVisibility: .visible) {
                Button("Leave", role: .destructive) { act { try store.leave(circleID); dismiss() } }
            }
    }
    private func act(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}

private struct DemoAgentStatusView: View {
    var body: some View {
        Screen {
            ContentCard {
                Label("Messages agent unavailable", systemImage: "bubble.left.and.bubble.right").font(.headline)
                Text("No verified managed address or account-linking API has been published. No conversation will be opened with a guessed recipient.")
                Text("Once connected, you will review and send the message yourself in Apple Messages. Kavach cannot read your personal inbox.").foregroundStyle(.secondary)
            }
            ContentCard {
                Text("Fictional starter prompt").font(.headline)
                Text("Someone claiming to be my bank asked for a code. What should I check?").textSelection(.enabled)
                Text("Do not send passwords, verification codes, or financial account details.").font(.caption)
            }
        }.navigationTitle("Messages agent")
    }
}
