import Foundation

// Foundation only — Tools/VKRedirectCheck.swift compiles and exercises this in CI.
enum Version {
    /// Component-wise numeric compare, so "1.0.12" beats "1.0.9" (a string
    /// compare gets that backwards and would offer a downgrade forever).
    /// Missing components count as 0: "1.1" > "1.0.7", "1.0" == "1.0.0".
    static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let a = parts(lhs), b = parts(rhs)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func parts(_ s: String) -> [Int] {
        s.split(whereSeparator: { !$0.isNumber }).map { Int($0) ?? 0 }
    }
}
