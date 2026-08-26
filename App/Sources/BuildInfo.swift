import Foundation

// CI rewrites this file before building (see .github/workflows/build.yml).
// The version lives in the binary itself because Info.plist proved unreliable:
// XcodeGen baked literal defaults, and under LiveContainer the guest app's
// bundle is not necessarily what Bundle.main hands back.
enum BuildInfo {
    static let version = "0.0.0-dev"
    static let build = "0"

    /// True for a local build CI never stamped — then fall back to the bundle.
    static var isPlaceholder: Bool { version == "0.0.0-dev" }
}
