import SwiftUI
import NotikaCore
import NotikaPostProcessing

struct PromptsTab: View {
    @State private var selectedMode: DictationMode = .literal

    var body: some View {
        VStack(spacing: 0) {
            Picker("Modus", selection: $selectedMode) {
                ForEach(DictationMode.allCases) { mode in
                    Text(mode.shortName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(16)

            Divider()

            ModePromptEditor(mode: selectedMode)
                .id(selectedMode)
        }
    }
}

private struct ModePromptEditor: View {
    let mode: DictationMode

    @State private var text: String = ""
    @State private var isDirty: Bool = false
    @State private var justSaved: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                    Text("Dieser Prompt wird an das gewählte LLM gesendet, bevor das Transkript verarbeitet wird.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if justSaved {
                    Label("Gespeichert", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .textEditorStyle(.plain)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(.quaternary)
                )
                .frame(minHeight: 260)
                .padding(.horizontal, 16)
                .onChange(of: text) { _, _ in
                    isDirty = true
                    justSaved = false
                }

            HStack {
                Button("Auf Standard zurücksetzen") {
                    let defaultText = PromptStore.defaultPrompt(for: mode)
                    text = defaultText
                    PromptStore.setCustomPrompt(nil, for: mode)
                    isDirty = false
                    withAnimation { justSaved = true }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Speichern") {
                    PromptStore.setCustomPrompt(text, for: mode)
                    isDirty = false
                    withAnimation { justSaved = true }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isDirty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .onAppear { text = PromptStore.effectivePrompt(for: mode) }
    }
}

#Preview {
    PromptsTab().frame(width: 620, height: 480)
}
