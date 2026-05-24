import SwiftUI

/// Shows the loaded image and, once available, the cutout result on a
/// transparency checkerboard. A segmented control flips between the two so the
/// user can judge the cutout against the original.
struct PreviewView: View {
    let original: NSImage
    let result: NSImage?
    let resultURL: URL?
    let isProcessing: Bool

    enum Side: String, CaseIterable, Identifiable {
        case original = "Original"
        case result = "Result"
        var id: String { rawValue }
    }

    @State private var side: Side = .original

    private var showingResult: Bool { side == .result && result != nil }

    var body: some View {
        VStack(spacing: 12) {
            if result != nil {
                Picker("View", selection: $side) {
                    ForEach(Side.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 240)
                .disabled(isProcessing)
            }

            imageStage
        }
        .padding(20)
        .onChange(of: resultURL) { _, newValue in
            // Surface the freshly produced cutout automatically.
            side = newValue == nil ? .original : .result
        }
    }

    @ViewBuilder
    private var imageStage: some View {
        ZStack {
            if showingResult {
                Checkerboard()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            displayedImage
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .modifier(DragOutResult(url: showingResult ? resultURL : nil))

            if isProcessing {
                ProcessingOverlay()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        )
        .accessibilityLabel(showingResult ? "Cutout result" : "Original image")
    }

    private var displayedImage: Image {
        if showingResult, let result {
            return Image(nsImage: result)
        }
        return Image(nsImage: original)
    }
}

/// Lets the user drag the finished cutout straight into Finder or another app.
private struct DragOutResult: ViewModifier {
    let url: URL?

    func body(content: Content) -> some View {
        if let url {
            content.onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        } else {
            content
        }
    }
}

private struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.black.opacity(0.35))
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Working…")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .transition(.opacity)
    }
}
