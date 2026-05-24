import Foundation

/// What to do with the area behind the subject once it's segmented.
enum BackgroundMode: Equatable, Sendable {
    /// Leave the background transparent (a standard cutout PNG).
    case transparent
    /// Fill the background with a solid opaque color.
    case solidColor(red: Int, green: Int, blue: Int)

    static let white = BackgroundMode.solidColor(red: 255, green: 255, blue: 255)
}

/// A single, fully-specified background-removal job.
///
/// This is a value type so it can cross to a background queue without tripping
/// Swift's concurrency checks. The view layer builds one of these from the
/// current UI state and hands it to `RembgService`.
struct RemovalRequest: Sendable {
    var inputURL: URL
    var outputURL: URL
    var model: RembgModel
    var background: BackgroundMode
    /// Run rembg's alpha-matting pass to refine boundaries (slower, softer edges).
    var alphaMatting: Bool
    /// Erode size for alpha matting. Higher = better on fuzzy subjects (hair/fur).
    var alphaMattingErodeSize: Int
    /// Post-process the mask to smooth small artifacts (`-ppm`).
    var postProcessMask: Bool

    /// The exact argument list passed to the `rembg` executable.
    var arguments: [String] {
        var args = ["i", "-m", model.id]

        if alphaMatting {
            args += ["-a", "-ae", String(alphaMattingErodeSize)]
        }
        if postProcessMask {
            args.append("-ppm")
        }
        if case let .solidColor(red, green, blue) = background {
            args += ["-bgc", String(red), String(green), String(blue), "255"]
        }

        args += [inputURL.path, outputURL.path]
        return args
    }
}
