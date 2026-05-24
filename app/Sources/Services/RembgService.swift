import Foundation

/// Errors surfaced to the user, each mapped to a concrete next step.
///
/// The cases mirror the "Common pitfalls" section of the background-removal
/// skill so the UI can tell the user exactly how to recover.
enum RembgError: LocalizedError {
    case executableNotFound
    case missingCLIExtras
    case modelDownloadFailed(String)
    case processFailed(exitCode: Int32, message: String)
    case noOutputProduced

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Couldn't find the rembg command."
        case .missingCLIExtras:
            return "rembg is installed without its command-line extras."
        case .modelDownloadFailed(let detail):
            return "The segmentation model couldn't be downloaded.\n\(detail)"
        case .processFailed(let exitCode, let message):
            return "rembg exited with code \(exitCode).\n\(message)"
        case .noOutputProduced:
            return "rembg finished but produced no output file."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .executableNotFound:
            return "Install it with:  pip install \"rembg[cli]\"\nThen set its path in Settings if it still isn't found."
        case .missingCLIExtras:
            return "Reinstall with the CLI extras:  pip install \"rembg[cli]\""
        case .modelDownloadFailed:
            return "Check your internet connection — the first use of a model downloads its weights (50–400 MB)."
        case .processFailed:
            return "Try a model that matches your subject, or a different image."
        case .noOutputProduced:
            return "Try running again, or pick a different model."
        }
    }
}

/// Wraps the `rembg` command-line tool.
///
/// `rembg` runs ONNX segmentation models locally and writes a transparent PNG.
/// This service locates the binary, runs a single image through it, and turns
/// non-zero exits into actionable `RembgError`s.
struct RembgService: Sendable {

    /// Locations a Homebrew/pip install of `rembg` commonly lands in. Checked in
    /// order before falling back to the user's login shell `PATH`.
    private static let candidatePaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.local/bin/rembg",
            "/opt/homebrew/bin/rembg",
            "/usr/local/bin/rembg",
            "/opt/homebrew/anaconda3/bin/rembg",
        ]
    }()

    /// Resolves the path to the `rembg` executable.
    ///
    /// A GUI app launched from Finder inherits a minimal `PATH`, so we can't rely
    /// on `env`. We check known install locations first (fast), honor an explicit
    /// user override, then fall back to asking the login shell where `rembg` lives.
    static func locateExecutable(override: String?) -> URL? {
        if let override, !override.isEmpty {
            let expanded = (override as NSString).expandingTildeInPath
            if FileManager.default.isExecutableFile(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }
        }

        for path in candidatePaths where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        return locateViaLoginShell()
    }

    /// Asks the user's login shell to resolve `rembg`, matching the environment
    /// the Terminal uses (where the tool was likely installed).
    private static func locateViaLoginShell() -> URL? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-lc", "command -v rembg"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// Runs one image through `rembg` and writes the result to `request.outputURL`.
    ///
    /// The blocking `Process` work runs on a background queue; nothing non-`Sendable`
    /// crosses the continuation boundary.
    func remove(_ request: RemovalRequest, executable: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try Self.runProcess(request, executable: executable)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func runProcess(_ request: RemovalRequest, executable: URL) throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = request.arguments

        // Give the subprocess a sane PATH (the model cache and any helper tools
        // live under standard bin dirs) while preserving HOME for the ~/.u2net cache.
        var environment = ProcessInfo.processInfo.environment
        let extraPaths = [
            executable.deletingLastPathComponent().path,
            "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
        ]
        let existingPath = environment["PATH"] ?? ""
        environment["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")
        process.environment = environment

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
        } catch {
            throw RembgError.executableNotFound
        }

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let stderr = String(decoding: errorData, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw mapFailure(exitCode: process.terminationStatus, stderr: stderr)
        }

        // A zero exit with no file means something silently went wrong.
        guard FileManager.default.fileExists(atPath: request.outputURL.path) else {
            throw RembgError.noOutputProduced
        }
    }

    /// Translates rembg's stderr into a specific `RembgError` where possible.
    private static func mapFailure(exitCode: Int32, stderr: String) -> RembgError {
        if stderr.contains("ModuleNotFoundError") && stderr.contains("filetype") {
            return .missingCLIExtras
        }
        if stderr.localizedCaseInsensitiveContains("download")
            || stderr.localizedCaseInsensitiveContains("urlopen")
            || stderr.localizedCaseInsensitiveContains("connection") {
            return .modelDownloadFailed(lastMeaningfulLine(stderr))
        }
        return .processFailed(exitCode: exitCode, message: lastMeaningfulLine(stderr))
    }

    /// Pulls the most informative trailing lines out of a noisy traceback.
    private static func lastMeaningfulLine(_ stderr: String) -> String {
        let lines = stderr
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return "No error output." }
        return lines.suffix(3).joined(separator: "\n")
    }
}
