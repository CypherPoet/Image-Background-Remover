import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var showInspector = true
    @State private var isDropTargeted = false

    var body: some View {
        @Bindable var model = model

        canvas
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                model.load(url: url)
                return true
            } isTargeted: { isDropTargeted = $0 }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !model.rembgAvailable {
                    RembgMissingBanner()
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                StatusBar(model: model)
            }
            .toolbar { toolbarContent(model: model) }
            .inspector(isPresented: $showInspector) {
                OptionsPanel(model: model)
                    .inspectorColumnWidth(min: 260, ideal: 300, max: 360)
            }
            .fileImporter(
                isPresented: $model.isImporterPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                if case let .success(urls) = result, let url = urls.first {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    model.load(url: url)
                }
            }
            .fileExporter(
                isPresented: $model.isExporterPresented,
                document: PNGDocument(data: model.resultData() ?? Data()),
                contentType: .png,
                defaultFilename: model.suggestedExportName
            ) { _ in }
            .alert(
                model.activeError?.title ?? "Error",
                isPresented: Binding(
                    get: { model.activeError != nil },
                    set: { if !$0 { model.activeError = nil } }
                ),
                presenting: model.activeError
            ) { _ in
                Button("OK", role: .cancel) { model.activeError = nil }
            } message: { error in
                Text(error.message)
            }
    }

    @ViewBuilder
    private var canvas: some View {
        if let input = model.inputImage {
            PreviewView(
                original: input,
                result: model.resultImage,
                resultURL: model.resultURL,
                isProcessing: model.isProcessing
            )
        } else {
            DropZoneView(isTargeted: isDropTargeted) {
                model.isImporterPresented = true
            }
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent(model: AppModel) -> some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                model.isImporterPresented = true
            } label: {
                Label("Open", systemImage: "photo.badge.plus")
            }
            .help("Open an image (⌘O)")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                Task { await model.removeBackground() }
            } label: {
                Label("Remove Background", systemImage: "scissors")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.inputURL == nil || model.isProcessing)
            .help("Remove the background (⌘R)")

            Button {
                model.isExporterPresented = true
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .disabled(model.resultURL == nil)
            .help("Save the cutout (⌘S)")

            Button {
                showInspector.toggle()
            } label: {
                Label("Options", systemImage: "slider.horizontal.3")
            }
            .help("Show or hide options")
        }
    }
}

/// Persistent banner warning that the rembg tool wasn't found.
private struct RembgMissingBanner: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text("rembg isn't installed or couldn't be found.")
                .foregroundStyle(.white)
            Spacer()
            Button("Settings…") { openSettings() }
                .buttonStyle(.bordered)
                .tint(.white)
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.orange)
    }
}

/// Bottom status strip: current model, progress message, and timing.
private struct StatusBar: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            if model.isProcessing {
                ProgressView().controlSize(.small)
            }
            Text(statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if let duration = model.lastDurationDescription, !model.isProcessing {
                Text(duration)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var statusText: String {
        if let message = model.statusMessage { return message }
        if model.inputURL == nil { return "Drop or open an image to begin." }
        return "Model: \(model.model.displayName)"
    }
}
