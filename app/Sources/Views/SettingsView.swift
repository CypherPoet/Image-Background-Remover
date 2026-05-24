import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            RembgSettings()
                .tabItem { Label("rembg", systemImage: "terminal") }
        }
        .scenePadding()
        .frame(width: 460)
    }
}

private struct GeneralSettings: View {
    @AppStorage(DefaultsKey.model) private var defaultModelID = RembgModel.default.id
    @AppStorage(DefaultsKey.alphaMatting) private var defaultAlphaMatting = false

    var body: some View {
        Form {
            Picker("Default model", selection: $defaultModelID) {
                ForEach(RembgModel.grouped, id: \.category) { group in
                    Section(group.category.rawValue) {
                        ForEach(group.models) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                }
            }

            Toggle("Use alpha matting by default", isOn: $defaultAlphaMatting)

            Text("Defaults apply to new windows. The model and edge options can still be changed per image in the Options panel.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .formStyle(.grouped)
    }
}

private struct RembgSettings: View {
    @Environment(AppModel.self) private var model
    @AppStorage(DefaultsKey.rembgPath) private var rembgPath = ""
    @State private var resolvedPath: String?

    var body: some View {
        Form {
            Section("Executable Path") {
                TextField("Path to rembg", text: $rembgPath, prompt: Text("Auto-detect"))
                    .textFieldStyle(.roundedBorder)
                Text("Leave blank to auto-detect. Set this if rembg lives in a non-standard location (for example, a virtualenv).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Status") {
                LabeledContent("Detected") {
                    if let resolvedPath {
                        Text(resolvedPath)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Not found", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                Button("Detect Again") { detect() }
            }

            Section {
                Text("Install rembg with:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("pip install \"rembg[cli]\"")
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: detect)
        .onChange(of: rembgPath) { detect() }
    }

    private func detect() {
        let override = rembgPath.isEmpty ? nil : rembgPath
        resolvedPath = RembgService.locateExecutable(override: override)?.path
        model.refreshAvailability()
    }
}
