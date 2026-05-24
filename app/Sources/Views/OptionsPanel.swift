import SwiftUI

/// The inspector panel: model selection and output options. Lives in the
/// trailing `.inspector` so the canvas keeps the focus.
struct OptionsPanel: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Model") {
                Picker("Subject", selection: $model.model) {
                    ForEach(RembgModel.grouped, id: \.category) { group in
                        Section(group.category.rawValue) {
                            ForEach(group.models) { candidate in
                                Text(candidate.displayName).tag(candidate)
                            }
                        }
                    }
                }
                .labelsHidden()

                Text(model.model.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Background") {
                Picker("Background", selection: $model.backgroundMode) {
                    ForEach(AppModel.BackgroundChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if model.backgroundMode == .custom {
                    ColorPicker("Fill color", selection: $model.customColor, supportsOpacity: false)
                }
            }

            Section("Edge Refinement") {
                Toggle("Alpha matting", isOn: $model.alphaMatting)
                Text("A slower second pass that softens hair, fur, and fuzzy outlines.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if model.alphaMatting {
                    LabeledContent("Erode size") {
                        Text("\(Int(model.erodeSize))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $model.erodeSize, in: 0...30, step: 1) {
                        Text("Erode size")
                    } minimumValueLabel: {
                        Text("Sharp").font(.caption2)
                    } maximumValueLabel: {
                        Text("Fuzzy").font(.caption2)
                    }
                    .labelsHidden()
                }

                Toggle("Smooth mask artifacts", isOn: $model.postProcessMask)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 260)
    }
}
