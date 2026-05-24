import SwiftUI

/// The empty-state target shown before an image is loaded. Accepts a dropped
/// file or a click to open the system file picker.
struct DropZoneView: View {
    var isTargeted: Bool
    var onBrowse: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tint)

            VStack(spacing: 6) {
                Text("Drop an image here")
                    .font(.title2.weight(.semibold))
                Text("or click to browse — PNG, JPEG, HEIC, WebP, TIFF")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("Choose Image…", action: onBrowse)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.quaternary.opacity(isTargeted ? 0.6 : 0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.4)),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [8, 6])
                )
        )
        .padding(24)
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .contentShape(Rectangle())
        .onTapGesture(perform: onBrowse)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Image drop zone")
        .accessibilityHint("Drop an image or activate to browse for a file")
        .accessibilityAddTraits(.isButton)
    }
}
