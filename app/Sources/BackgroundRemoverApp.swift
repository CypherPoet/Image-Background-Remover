import SwiftUI

@main
struct BackgroundRemoverApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 1040, height: 680)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Image…") { model.isImporterPresented = true }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .saveItem) {
                Button("Save Result…") { model.isExporterPresented = true }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(model.resultURL == nil)

                Button("Remove Background") {
                    Task { await model.removeBackground() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(model.inputURL == nil || model.isProcessing)

                Button("Clear", role: .destructive) { model.clear() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                    .disabled(model.inputURL == nil)
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
