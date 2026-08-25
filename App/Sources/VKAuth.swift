import SwiftUI
import WebKit

// In-app VK OAuth (implicit flow via Kate Mobile app_id) — user logs in on vk.com, we grab the token.
struct VKAuthWeb: UIViewRepresentable {
    let onToken: (String) -> Void
    var onError: (String) -> Void = { _ in }

    // Kate Mobile app_id — the classic client that still grants the messages scope.
    // No revoke=1: VK then reuses the existing grant, so a returning user skips the consent screen.
    private var authURL: URL {
        URL(string: "https://oauth.vk.com/authorize?client_id=2685278" +
            "&scope=friends,messages,photos,docs,status,groups,offline" +
            "&redirect_uri=https://oauth.vk.com/blank.html" +
            "&display=mobile&response_type=token&v=5.199")!
    }

    func makeCoordinator() -> Coordinator { Coordinator(onToken: onToken, onError: onError) }

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.navigationDelegate = context.coordinator
        wv.load(URLRequest(url: authURL))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onToken: (String) -> Void
        let onError: (String) -> Void
        private var done = false
        init(onToken: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onToken = onToken; self.onError = onError
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = action.request.url, handle(url) { decisionHandler(.cancel); return }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url { _ = handle(url) }
        }

        /// Returns true when the URL was the final redirect and was consumed.
        private func handle(_ url: URL) -> Bool {
            guard !done, let outcome = VKRedirect.outcome(for: url) else { return false }
            done = true
            switch outcome {
            case .token(let t): onToken(t)
            case .failure(let msg): onError(msg)
            }
            return true
        }
    }
}
