import Foundation

struct Account: Codable, Identifiable, Equatable {
    var id: Int          // VK user id
    var name: String
    var token: String
    var photo: String?
}

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published var activeId: Int?

    private let key = "vk_accounts"

    init() { load() }

    var active: Account? { accounts.first { $0.id == activeId } }
    var vk: VK? { active.map { VK(token: $0.token) } }

    func addAccount(token: String) async throws {
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let me = try await VK(token: t).user(id: nil)
        let acc = Account(id: me.id,
                          name: "\(me.first_name) \(me.last_name)",
                          token: t,
                          photo: me.photo_200 ?? me.photo_100)
        accounts.removeAll { $0.id == acc.id }
        accounts.append(acc)
        activeId = acc.id
        save()
    }

    func switchTo(_ id: Int) { activeId = id; save() }

    func remove(_ id: Int) {
        accounts.removeAll { $0.id == id }
        if activeId == id { activeId = accounts.first?.id }
        save()
        clearIfEmpty()
    }

    private struct Blob: Codable { let accounts: [Account]; let activeId: Int? }

    // Keychain alone lost the session: under LiveContainer the guest app's
    // keychain does not reliably survive a reinstall, so every update meant
    // logging in again. Mirror into the app container, which does survive.
    // ponytail: container file instead of Keychain-only — protected while
    // locked, and the device is the user's own; Keychain stays the primary.
    private static var mirrorURL: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: true)
            .appendingPathComponent("accounts.json")
    }

    private func save() {
        guard let d = try? JSONEncoder().encode(Blob(accounts: accounts, activeId: activeId)) else { return }
        if let s = String(data: d, encoding: .utf8) { Keychain.set(s, for: key) }
        if let url = Self.mirrorURL {
            try? d.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    private func load() {
        var blob: Blob?
        if let s = Keychain.get(key), let d = s.data(using: .utf8) {
            blob = try? JSONDecoder().decode(Blob.self, from: d)
        }
        var fromMirror = false
        if blob == nil, let url = Self.mirrorURL, let d = try? Data(contentsOf: url) {
            blob = try? JSONDecoder().decode(Blob.self, from: d)
            fromMirror = blob != nil
        }
        guard let blob else { return }
        accounts = blob.accounts
        activeId = blob.activeId ?? blob.accounts.first?.id
        if fromMirror { save() }   // put it back in the Keychain for next time
    }

    /// Wipe both copies — otherwise a removed account walks back in from the mirror.
    private func clearIfEmpty() {
        guard accounts.isEmpty else { return }
        Keychain.delete(key)
        if let url = Self.mirrorURL { try? FileManager.default.removeItem(at: url) }
    }
}
