import Foundation

// Runnable check for the OAuth redirect parser — the exact spot where in-app
// login broke once (an intermediate VK ID URL's access_token was accepted).
// Built and run by CI: swiftc App/Sources/VKRedirect.swift Tools/VKRedirectCheck.swift

func expect(_ url: String, _ want: VKRedirect.Outcome?, _ what: String) {
    let got = VKRedirect.outcome(for: URL(string: url)!)
    guard got == want else {
        FileHandle.standardError.write("FAIL \(what)\n  want: \(String(describing: want))\n  got:  \(String(describing: got))\n".data(using: .utf8)!)
        exit(1)
    }
}

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

print("VKRedirect: all checks passed")
