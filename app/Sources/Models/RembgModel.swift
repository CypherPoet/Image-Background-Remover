import Foundation

/// A `rembg` segmentation model the user can choose from.
///
/// The curated list and the per-subject guidance below come directly from the
/// `image-background-removal` skill: each model is trained for a particular kind
/// of subject, and picking the wrong one produces visibly broken cutouts.
struct RembgModel: Identifiable, Hashable, Sendable {
    /// The exact name passed to `rembg -m`.
    let id: String
    let displayName: String
    /// One-line guidance shown next to the picker.
    let detail: String
    let category: Category

    enum Category: String, CaseIterable, Identifiable, Sendable {
        case people = "People"
        case general = "Products & General"
        case detail = "Fine Detail"
        case illustration = "Illustration"
        case fast = "Fast / Batch"

        var id: String { rawValue }
    }
}

extension RembgModel {
    /// The models surfaced in the UI, ordered the way they appear in the picker.
    static let all: [RembgModel] = [
        // People
        RembgModel(id: "birefnet-portrait", displayName: "BiRefNet Portrait",
                   detail: "Best quality for people and headshots; handles hair edges well.",
                   category: .people),
        RembgModel(id: "u2net_human_seg", displayName: "U²-Net Human",
                   detail: "Faster human segmentation when you don't need maximum quality.",
                   category: .people),

        // Products & general
        RembgModel(id: "birefnet-general", displayName: "BiRefNet General",
                   detail: "Best all-purpose quality: products, animals, objects, scenes.",
                   category: .general),
        RembgModel(id: "u2net", displayName: "U²-Net",
                   detail: "Solid, faster general-purpose default.",
                   category: .general),
        RembgModel(id: "isnet-general-use", displayName: "IS-Net General",
                   detail: "Balanced general-purpose alternative to U²-Net.",
                   category: .general),
        RembgModel(id: "birefnet-cod", displayName: "BiRefNet Camouflage",
                   detail: "For low-contrast subjects that blend into the background.",
                   category: .general),

        // Fine detail
        RembgModel(id: "birefnet-dis", displayName: "BiRefNet Dichotomous",
                   detail: "Preserves thin structures: hair, fur, plants, lace, glass. Pair with alpha matting.",
                   category: .detail),
        RembgModel(id: "birefnet-hrsod", displayName: "BiRefNet High-Res",
                   detail: "Tuned for high-resolution images where fine detail matters.",
                   category: .detail),
        RembgModel(id: "birefnet-massive", displayName: "BiRefNet Massive",
                   detail: "Highest-quality, heaviest model. Slowest on CPU.",
                   category: .detail),

        // Illustration
        RembgModel(id: "isnet-anime", displayName: "IS-Net Anime",
                   detail: "Flat, cel-shaded 2D art and line work only — not photoreal CGI.",
                   category: .illustration),
        RembgModel(id: "u2net_cloth_seg", displayName: "U²-Net Clothing",
                   detail: "Per-garment masks for clothing (upper, lower, full body).",
                   category: .illustration),

        // Fast / batch
        RembgModel(id: "birefnet-general-lite", displayName: "BiRefNet General Lite",
                   detail: "Lighter BiRefNet; good quality-for-speed tradeoff.",
                   category: .fast),
        RembgModel(id: "u2netp", displayName: "U²-Net Lite",
                   detail: "Smallest, fastest model. Best for large batches on CPU.",
                   category: .fast),
        RembgModel(id: "silueta", displayName: "Silueta",
                   detail: "Small, fast U²-Net variant.",
                   category: .fast),
    ]

    static let `default` = all.first { $0.id == "birefnet-general" } ?? all[0]

    static func named(_ id: String) -> RembgModel? {
        all.first { $0.id == id }
    }

    /// Models grouped by category, preserving the order in `all`.
    static var grouped: [(category: Category, models: [RembgModel])] {
        Category.allCases.compactMap { category in
            let models = all.filter { $0.category == category }
            return models.isEmpty ? nil : (category, models)
        }
    }
}
