import SwiftUI
import AppKit
import KirjoCore

struct HistoryDetailSheet: View {
    let entry: DictationHistoryEntry
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var copied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(entry.timestamp, format: .dateTime.day().month().year().hour().minute())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onClose()
                } label: { Image(systemName: "xmark.circle.fill").imageScale(.large) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            ScrollView {
                Text(entry.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Button(role: .destructive, action: onDelete) {
                    Label("Löschen", systemImage: "trash")
                }
                Spacer()
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(entry.text, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Kopiert!" : "Kopieren", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 520, height: 380)
    }
}
