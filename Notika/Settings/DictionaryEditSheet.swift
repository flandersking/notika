import SwiftUI
import NotikaCore

struct DictionaryEditSheet: View {
    let initialTerm: String
    let initialLanguage: Language
    let initialCategory: DictionaryCategory
    let title: String
    let onSave: (String, Language, DictionaryCategory) -> Void
    let onCancel: () -> Void

    @State private var term: String
    @State private var language: Language
    @State private var category: DictionaryCategory

    init(
        initialTerm: String = "",
        initialLanguage: Language = .german,
        initialCategory: DictionaryCategory = .general,
        title: String,
        onSave: @escaping (String, Language, DictionaryCategory) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialTerm = initialTerm
        self.initialLanguage = initialLanguage
        self.initialCategory = initialCategory
        self.title = title
        self.onSave = onSave
        self.onCancel = onCancel
        _term = State(initialValue: initialTerm)
        _language = State(initialValue: initialLanguage)
        _category = State(initialValue: initialCategory)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3).bold()

            Form {
                TextField("Begriff", text: $term)
                    .textFieldStyle(.roundedBorder)

                Picker("Sprache", selection: $language) {
                    Text("Deutsch").tag(Language.german)
                    Text("Englisch").tag(Language.english)
                }

                Picker("Kategorie", selection: $category) {
                    ForEach(DictionaryCategory.allCases, id: \.self) { cat in
                        Text(cat.displayName).tag(cat)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Abbrechen", action: onCancel)
                Spacer()
                Button("Speichern") {
                    let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed, language, category)
                }
                .buttonStyle(.borderedProminent)
                .disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420, height: 320)
    }
}
