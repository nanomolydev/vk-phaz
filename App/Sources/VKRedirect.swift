import Foundation

// Pure parsing of the VK OAuth redirect. Foundation only, no WebKit —
// so Tools/VKRedirectCheck.swift can compile and run it in CI.
enum VKRedirect {
    /// Our token only ever arrives at redirect_uri (oauth.vk.com/blank.html).
    /// The VK ID login flow walks through other URLs that also carry an
    /// `access_token=` (anonymous/service tokens); accepting those hands the
    /// app a token that every API call rejects.
    static func isRedirect(_ url: URL) -> Bool {
        url.host?.hasSuffix("vk.com") == true && url.path.hasPrefix("/blank")
    }

    /// Fragment wins over query — VK puts the real token in the fragment.
    static func params(from url: URL) -> [String: String] {
        var out: [String: String] = [:]
        for chunk in [url.fragment, url.query] {
            guard let chunk, !chunk.isEmpty else { continue }
            for part in chunk.split(separator: "&") {
                let kv = part.split(separator: "=", maxSplits: 1)
                guard kv.count == 2, out[String(kv[0])] == nil else { continue }
                let raw = String(kv[1])
                out[String(kv[0])] = raw.removingPercentEncoding ?? raw
            }
        }
        return out
    }

    enum Outcome: Equatable { case token(String), failure(String) }

    /// nil = not the redirect yet, keep browsing.
    static func outcome(for url: URL) -> Outcome? {
        guard isRedirect(url) else { return nil }
        let p = params(from: url)
        if let t = p["access_token"], !t.isEmpty { return .token(t) }
        if let e = p["error"] { return .failure(p["error_description"] ?? e) }
        return nil
    }
}
