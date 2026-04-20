import SwiftUI
import KirjoCore

struct WhisperDownloadConfirmSheet: View {
    let model: WhisperModelID
    let onActivate: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("\(model.displayName) ist installiert")
                .font(.title3).bold()
            Text("Als Standard-Spracherkennung verwenden? Du kannst das jederzeit in den Einstellungen ändern.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            HStack {
                Button("Nein, später", action: onLater)
                Spacer()
                Button("Ja, jetzt aktivieren", action: onActivate)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(28)
        .frame(width: 460)
    }
}
