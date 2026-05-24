import SwiftUI
import UniformTypeIdentifiers

/// A read-only document used solely to drive `.fileExporter` for the finished
/// PNG. The bytes are produced by rembg; we just hand them to the save panel.
struct PNGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
