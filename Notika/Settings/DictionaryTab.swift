import AppKit
import SwiftUI
import UniformTypeIdentifiers
import NotikaCore
import NotikaDictionary

struct DictionaryTab: View {
    @State private var store = DictionaryStore()
    @State private var terms: [DictionaryTerm] = []
    @State private var searchText: String = ""
    @State private var languageFilter: LanguageFilter = .all
    @State private var categoryFilter: CategoryFilter = .all
    @State private var editingEntry: DictionaryTerm?
    @State private var showingAdd: Bool = false
    @State private var toast: String?
    @State private var deleteConfirmEntry: DictionaryTerm?

    enum LanguageFilter: Hashable { case all, only(Language) }
    enum CategoryFilter: Hashable { case all, only(DictionaryCategory) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbarView
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            if filteredTerms.isEmpty {
                emptyState
            } else {
                Table(filteredTerms) {
                    TableColumn("Begriff") { term in
                        Text(term.term).lineLimit(1)
                    }
                    TableColumn("Sprache") { term in
                        Text(languageLabel(term.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 80, ideal: 100)
                    TableColumn("Kategorie") { term in
                        Text(term.category?.displayName ?? "—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 100, ideal: 120)
                    TableColumn("Aktionen") { term in
                        HStack(spacing: 6) {
                            Button("Bearbeiten") { editingEntry = term }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                            Button(role: .destructive) {
                                deleteConfirmEntry = term
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }
                    }
                    .width(min: 140, ideal: 160)
                }
            }

            if let toast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(toast)
                        .font(.footnote)
                    Spacer()
                }
                .padding(10)
                .background(.regularMaterial)
            }
        }
        .sheet(isPresented: $showingAdd) {
            DictionaryEditSheet(
                title: "Neuer Eintrag",
                onSave: { term, lang, cat in
                    store.addTerm(term, language: lang, category: cat)
                    showingAdd = false
                    reload()
                },
                onCancel: { showingAdd = false }
            )
        }
        .sheet(item: $editingEntry) { entry in
            DictionaryEditSheet(
                initialTerm: entry.term,
                initialLanguage: entry.language ?? .german,
                initialCategory: entry.category ?? .general,
                title: "Eintrag bearbeiten",
                onSave: { term, lang, cat in
                    store.updateTerm(entry, newTerm: term, newLanguage: lang, newCategory: cat)
                    editingEntry = nil
                    reload()
                },
                onCancel: { editingEntry = nil }
            )
        }
        .alert("Eintrag löschen?", isPresented: Binding(
            get: { deleteConfirmEntry != nil },
            set: { if !$0 { deleteConfirmEntry = nil } }
        )) {
            Button("Abbrechen", role: .cancel) { deleteConfirmEntry = nil }
            Button("Löschen", role: .destructive) {
                if let entry = deleteConfirmEntry {
                    store.deleteTerm(entry)
                    deleteConfirmEntry = nil
                    reload()
                }
            }
        } message: {
            if let entry = deleteConfirmEntry {
                Text("„\(entry.term)“ wird aus dem Wörterbuch entfernt.")
            }
        }
        .task { reload() }
    }

    private var toolbarView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Suchen …", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Picker("Sprache", selection: $languageFilter) {
                    Text("Alle").tag(LanguageFilter.all)
                    Text("Deutsch").tag(LanguageFilter.only(.german))
                    Text("Englisch").tag(LanguageFilter.only(.english))
                }
                .frame(minWidth: 120)

                Picker("Kategorie", selection: $categoryFilter) {
                    Text("Alle").tag(CategoryFilter.all)
                    ForEach(DictionaryCategory.allCases, id: \.self) { cat in
                        Text(cat.displayName).tag(CategoryFilter.only(cat))
                    }
                }
                .frame(minWidth: 140)
            }

            HStack(spacing: 8) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Neu", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button("CSV importieren …") { importCSV() }
                Button("CSV exportieren …") { exportCSV() }

                Spacer()

                Text("\(terms.count) Einträge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Noch keine Einträge",
            systemImage: "character.book.closed",
            description: Text("Füge Fachbegriffe, Namen oder Firmen hinzu, die die Spracherkennung besser verstehen soll.")
        )
        .frame(maxHeight: .infinity)
    }

    private var filteredTerms: [DictionaryTerm] {
        var result = terms
        if case .only(let lang) = languageFilter {
            result = result.filter { $0.languageRawValue == lang.rawValue }
        }
        if case .only(let cat) = categoryFilter {
            result = result.filter { $0.categoryRawValue == cat.rawValue }
        }
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !search.isEmpty {
            result = result.filter { $0.term.lowercased().contains(search) }
        }
        return result
    }

    private func languageLabel(_ language: Language?) -> String {
        switch language {
        case .german:  return "Deutsch"
        case .english: return "Englisch"
        case .none:    return "—"
        }
    }

    private func reload() {
        terms = store.allTerms()
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let result = try store.importCSV(from: url)
            reload()
            showToast("\(result.imported) importiert, \(result.skipped) übersprungen")
        } catch {
            showToast("Import fehlgeschlagen")
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "notika-woerterbuch.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportCSV(to: url)
            showToast("\(terms.count) Einträge exportiert")
        } catch {
            showToast("Export fehlgeschlagen")
        }
    }

    private func showToast(_ text: String) {
        toast = text
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            toast = nil
        }
    }
}

// Hinweis: `DictionaryTerm` ist bereits Identifiable (via SwiftData `@Model`),
// deshalb benötigen wir hier keine zusätzliche Konformitätsdeklaration.
