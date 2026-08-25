import Foundation

// Runnable check for the OAuth redirect parser — the exact spot where in-app
// login broke once (an intermediate VK ID URL's access_token was accepted).
// Built and run by CI: swiftc App/Sources/VKRedirect.swift Tools/VKRedirectCheck.swift

@main
enum VKRedirectCheck {
    static func expect(_ url: String, _ want: VKRedirect.Outcome?, _ what: String) {
        let got = VKRedirect.outcome(for: URL(string: url)!)
        guard got == want else {
            FileHandle.standardError.write("FAIL \(what)\n  want: \(String(describing: want))\n  got:  \(String(describing: got))\n".data(using: .utf8)!)
            exit(1)
        }
    }

    static func main() {
        // The real thing.
        expect("https://oauth.vk.com/blank.html#access_token=abc123&expires_in=0&user_id=1",
               .token("abc123"), "token from fragment")

        // The bug: VK ID intermediate URLs carry their own access_token. Must be ignored.
        expect("https://id.vk.com/auth?app_id=2685278&access_token=anonymous.deadbeef",
               nil, "anonymous token on id.vk.com ignored")
        expect("https://login.vk.com/?act=web_token&access_token=service.xyz",
               nil, "service token on login.vk.com ignored")

        // VK reporting a refusal — surface it instead of hanging on a blank page.
        expect("https://oauth.vk.com/blank.html#error=access_denied&error_description=User%20denied",
               .failure("User denied"), "error_description percent-decoded")
        expect("https://oauth.vk.com/blank.html#error=invalid_request",
               .failure("invalid_request"), "bare error code")

        // Nothing useful yet — keep browsing.
        expect("https://oauth.vk.com/blank.html", nil, "bare redirect page")
        expect("https://id.vk.com/auth", nil, "login page")

        versionChecks()
        print("VKRedirect + Version: all checks passed")
    }

    static func expectVersion(_ new: String, _ cur: String, _ want: Bool) {
        let got = Version.isNewer(new, than: cur)
        guard got == want else {
            FileHandle.standardError.write("FAIL isNewer(\(new), than: \(cur)) = \(got), want \(want)\n".data(using: .utf8)!)
            exit(1)
        }
    }

    static func versionChecks() {
        expectVersion("1.0.12", "1.0.9", true)    // the one string compare gets wrong
        expectVersion("1.0.9", "1.0.12", false)
        expectVersion("1.0.1", "1.0.1", false)    // same build: no nagging
        expectVersion("1.1", "1.0.7", true)
        expectVersion("1.0", "1.0.0", false)      // missing components are zeros
        expectVersion("2.0", "1.9.9", true)
        expectVersion("v1.0.3", "1.0.2", true)    // stray tag prefix survives
    }
}
