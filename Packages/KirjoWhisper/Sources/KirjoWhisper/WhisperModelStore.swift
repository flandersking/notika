import Foundation
import KirjoCore
import os
import WhisperKit

@MainActor
public final class WhisperModelStore {
    public let modelsDirectory: URL
    private let logger = Logger(subsystem: "de.dymny.kirjo.mac", category: "Whisper")
    private var activeProgresses: [WhisperModelID: WhisperModelDownloadProgress] = [:]
    private var activeTasks: [WhisperModelID: Task<Void, Never>] = [:]

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Kirjo/WhisperModels")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.modelsDirectory = dir
        // One-time Cleanup alter flacher Layout-Reste aus Phase-1b-2-pre-hotfix
        cleanupLegacyFlatLayout()
    }

    public init(modelsDirectory: URL) {
        self.modelsDirectory = modelsDirectory
        // One-time Cleanup alter flacher Layout-Reste aus Phase-1b-2-pre-hotfix
        cleanupLegacyFlatLayout()
    }

    /// WhisperKit legt Modelle unter `<modelsDirectory>/models/argmaxinc/whisperkit-coreml/<variant>/` ab.
    /// Wir spiegeln diese Struktur, damit `installedModels()` und `deleteModel()` die echten Dateien finden.
    public func diskPath(for model: WhisperModelID) -> URL {
        modelsDirectory
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
            .appendingPathComponent(model.rawValue)
    }

    public func installedModels() -> [WhisperModelID] {
        WhisperModelID.allCases.filter { id in
            let path = diskPath(for: id)
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path.path) else {
                return false
            }
            return !contents.isEmpty
        }
    }

    public func availableDiskSpace() -> Int64 {
        let resourceValues = try? modelsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return resourceValues?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    public func deleteModel(_ model: WhisperModelID) throws {
        let path = diskPath(for: model)
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
            logger.info("Whisper-Modell gelöscht: \(model.rawValue, privacy: .public)")
        }
        activeProgresses.removeValue(forKey: model)
    }

    public func startDownload(_ model: WhisperModelID) -> WhisperModelDownloadProgress {
        if let existing = activeProgresses[model] {
            return existing
        }
        let progress = WhisperModelDownloadProgress(modelID: model)
        activeProgresses[model] = progress

        let required = Int64(Double(model.approximateBytes) * 1.5)
        let available = availableDiskSpace()
        if available < required {
            progress.update(.failed(.insufficientDiskSpace(required: required, available: available)))
            return progress
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let modelDir = self.diskPath(for: model)
                try? FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

                // WhisperKit 0.18 API: variant, downloadBase, useBackgroundSession, from, ...
                let progressRef = progress
                let url = try await WhisperKit.download(
                    variant: model.rawValue,
                    downloadBase: self.modelsDirectory,
                    useBackgroundSession: false,
                    from: "argmaxinc/whisperkit-coreml",
                    progressCallback: { @Sendable foundationProgress in
                        let done = Int64(foundationProgress.completedUnitCount)
                        let total = Int64(foundationProgress.totalUnitCount)
                        Task { @MainActor in
                            progressRef.update(.downloading(bytesDownloaded: done, bytesTotal: total))
                        }
                    }
                )
                self.logger.info("Whisper-Modell geladen: \(model.rawValue, privacy: .public) → \(url.path, privacy: .public)")
                progress.update(.completed)
            } catch is CancellationError {
                progress.update(.cancelled)
            } catch {
                self.logger.error("Whisper-Download-Fehler: \(error.localizedDescription, privacy: .public)")
                progress.update(.failed(.downloadFailed(reason: error.localizedDescription)))
            }
        }
        activeTasks[model] = task
        return progress
    }

    public func cancelDownload(_ model: WhisperModelID) {
        activeTasks[model]?.cancel()
        activeTasks.removeValue(forKey: model)
        activeProgresses.removeValue(forKey: model)
        let path = diskPath(for: model)
        try? FileManager.default.removeItem(at: path)
    }

    private func cleanupLegacyFlatLayout() {
        // Phase 1b-2-Pre-Hotfix legte Modell-Verzeichnisse FLACH unter modelsDirectory ab.
        // Seit Hotfix liegen sie unter models/argmaxinc/whisperkit-coreml/.
        // Lösche die alten flachen Leichen — nur wenn sie leer sind (wir wollen keine echten User-Daten löschen).
        for candidate in WhisperModelID.allCases {
            let flatPath = modelsDirectory.appendingPathComponent(candidate.rawValue)
            guard FileManager.default.fileExists(atPath: flatPath.path),
                  let contents = try? FileManager.default.contentsOfDirectory(atPath: flatPath.path),
                  contents.isEmpty
            else { continue }
            try? FileManager.default.removeItem(at: flatPath)
            logger.info("Entfernte Legacy-leeren Ordner: \(flatPath.lastPathComponent, privacy: .public)")
        }
        // Zusätzlich: Der alte falsche Name „openai_whisper-large-v3-turbo" (Hotfix b3b4ce9 ersetzte ihn):
        let legacyTurbo = modelsDirectory.appendingPathComponent("openai_whisper-large-v3-turbo")
        if FileManager.default.fileExists(atPath: legacyTurbo.path),
           let contents = try? FileManager.default.contentsOfDirectory(atPath: legacyTurbo.path),
           contents.isEmpty {
            try? FileManager.default.removeItem(at: legacyTurbo)
        }
    }
}
