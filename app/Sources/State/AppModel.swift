import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Owns all mutable state for a background-removal session and drives the
/// `RembgService`. Marked `@MainActor` so view updates are always on the main
/// thread; the actual segmentation runs off-thread inside the service.
@Observable
@MainActor
final class AppModel {

    // MARK: Input / output

    private(set) var inputURL: URL?
    private(set) var inputImage: NSImage?
    private(set) var resultURL: URL?
    private(set) var resultImage: NSImage?

    // MARK: Options

    var model: RembgModel
    var backgroundMode: BackgroundChoice = .transparent
    var customColor: Color = .white
    var alphaMatting: Bool
    var erodeSize: Double = 15
    var postProcessMask: Bool = false

    /// UI-facing background choice. `RemovalRequest.BackgroundMode` is derived from
    /// this plus `customColor` at run time.
    enum BackgroundChoice: String, CaseIterable, Identifiable {
        case transparent = "Transparent"
        case white = "White"
        case custom = "Custom Color"
        var id: String { rawValue }
    }

    // MARK: Status

    private(set) var isProcessing = false
    private(set) var statusMessage: String?
    private(set) var lastDurationDescription: String?
    var activeError: PresentableError?

    /// Whether the rembg tool could be located on this machine.
    private(set) var rembgAvailable = true

    /// Bound to the file importer/exporter sheets so menu commands can trigger them.
    var isImporterPresented = false
    var isExporterPresented = false

    private let service = RembgService()

    init() {
        let defaults = UserDefaults.standard
        let storedModelID = defaults.string(forKey: DefaultsKey.model)
        self.model = storedModelID.flatMap(RembgModel.named) ?? .default
        self.alphaMatting = defaults.bool(forKey: DefaultsKey.alphaMatting)
        refreshAvailability()
    }

    // MARK: Availability

    func refreshAvailability() {
        let override = UserDefaults.standard.string(forKey: DefaultsKey.rembgPath)
        rembgAvailable = RembgService.locateExecutable(override: override) != nil
    }

    // MARK: Loading images

    /// Validates and loads an image the user dropped or picked. Clears any previous result.
    func load(url: URL) {
        guard isImageFile(url) else {
            activeError = PresentableError(
                title: "Unsupported file",
                message: "\(url.lastPathComponent) doesn't look like an image. Pick a PNG, JPEG, HEIC, WebP, or TIFF."
            )
            return
        }
        guard let image = NSImage(contentsOf: url) else {
            activeError = PresentableError(
                title: "Couldn't open image",
                message: "macOS couldn't read \(url.lastPathComponent)."
            )
            return
        }
        inputURL = url
        inputImage = image
        resultURL = nil
        resultImage = nil
        statusMessage = nil
        lastDurationDescription = nil
    }

    private func isImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return false }
        return type.conforms(to: .image)
    }

    // MARK: Removing the background

    func removeBackground() async {
        guard let inputURL else { return }

        let override = UserDefaults.standard.string(forKey: DefaultsKey.rembgPath)
        guard let executable = RembgService.locateExecutable(override: override) else {
            rembgAvailable = false
            present(RembgError.executableNotFound)
            return
        }
        rembgAvailable = true

        let output = makeOutputURL(for: inputURL)
        let request = RemovalRequest(
            inputURL: inputURL,
            outputURL: output,
            model: model,
            background: resolvedBackground(),
            alphaMatting: alphaMatting,
            alphaMattingErodeSize: Int(erodeSize),
            postProcessMask: postProcessMask
        )

        isProcessing = true
        statusMessage = "Removing background with \(model.displayName)…"
        resultURL = nil
        resultImage = nil
        let started = Date()

        defer { isProcessing = false }

        do {
            try await service.remove(request, executable: executable)
            guard let image = NSImage(contentsOf: output) else {
                throw RembgError.noOutputProduced
            }
            resultURL = output
            resultImage = image
            let elapsed = Date().timeIntervalSince(started)
            lastDurationDescription = String(format: "Done in %.1fs", elapsed)
            statusMessage = nil
            persistDefaults()
        } catch {
            statusMessage = nil
            present(error)
        }
    }

    private func resolvedBackground() -> BackgroundMode {
        switch backgroundMode {
        case .transparent: return .transparent
        case .white: return .white
        case .custom:
            let (r, g, b) = customColor.rgbComponents
            return .solidColor(red: r, green: g, blue: b)
        }
    }

    private func makeOutputURL(for input: URL) -> URL {
        let base = input.deletingPathExtension().lastPathComponent
        let unique = UUID().uuidString.prefix(8)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(base)-nobg-\(unique).png")
    }

    // MARK: Saving

    /// A sensible default filename for the export panel.
    var suggestedExportName: String {
        let base = inputURL?.deletingPathExtension().lastPathComponent ?? "cutout"
        let suffix = backgroundMode == .transparent ? "no-bg" : "background"
        return "\(base)-\(suffix).png"
    }

    /// The finished PNG's bytes, for the file exporter.
    func resultData() -> Data? {
        guard let resultURL else { return nil }
        return try? Data(contentsOf: resultURL)
    }

    // MARK: Reset

    func clear() {
        inputURL = nil
        inputImage = nil
        resultURL = nil
        resultImage = nil
        statusMessage = nil
        lastDurationDescription = nil
    }

    // MARK: Helpers

    private func present(_ error: Error) {
        if let rembgError = error as? RembgError {
            activeError = PresentableError(
                title: rembgError.errorDescription ?? "Background removal failed",
                message: rembgError.recoverySuggestion ?? ""
            )
        } else {
            activeError = PresentableError(
                title: "Background removal failed",
                message: error.localizedDescription
            )
        }
    }

    private func persistDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(model.id, forKey: DefaultsKey.model)
        defaults.set(alphaMatting, forKey: DefaultsKey.alphaMatting)
    }
}

/// A user-presentable error with a title and a recovery message.
struct PresentableError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum DefaultsKey {
    static let model = "defaultModelID"
    static let alphaMatting = "defaultAlphaMatting"
    static let rembgPath = "rembgPath"
}

extension Color {
    /// 0–255 RGB components, resolved through the sRGB color space.
    var rgbComponents: (red: Int, green: Int, blue: Int) {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? .white
        return (
            Int((nsColor.redComponent * 255).rounded()),
            Int((nsColor.greenComponent * 255).rounded()),
            Int((nsColor.blueComponent * 255).rounded())
        )
    }
}
