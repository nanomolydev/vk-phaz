import SwiftUI

// In-app updates for a sideloaded build: ask GitHub Releases what the latest
// tag is, and hand the .ipa to whatever installed this app.
// iOS can't swap the binary itself — the sideloader does the install.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    // ponytail: repo hardcoded — it's this app's own repo, not a setting.
    private static let latestAPI = URL(string: "https://api.github.com/repos/nanomolydev/vk-phaz/releases/latest")!

    struct Release: Equatable {
        let version: String
        let ipa: URL?
        let page: URL?
        let notes: String
    }

    @Published private(set) var latest: Release?     // set only when it's actually newer
    @Published private(set) var checking = false
    @Published private(set) var error: String?
    @Published private(set) var checkedOnce = false

    /// Stamped into the binary by CI; the bundle is only a fallback for local builds.
    var current: String { BuildInfo.isPlaceholder ? Bundle.main.shortVersion : BuildInfo.version }
    var currentBuild: String { BuildInfo.isPlaceholder ? Bundle.main.buildNumber : BuildInfo.build }

    private struct Wire: Decodable {
        let tag_name: String
        let body: String?
        let html_url: String?
        let assets: [Asset]
        struct Asset: Decodable { let name: String; let browser_download_url: String }
    }

    func check() async {
        guard !checking else { return }
        checking = true; error = nil
        defer { checking = false; checkedOnce = true }
        do {
            var req = URLRequest(url: Self.latestAPI)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 404 {
                latest = nil; return   // no releases published yet
            }
            let w = try JSONDecoder().decode(Wire.self, from: data)
            let version = w.tag_name.hasPrefix("v") ? String(w.tag_name.dropFirst()) : w.tag_name
            guard Version.isNewer(version, than: current) else { latest = nil; return }
            let ipa = w.assets.first { $0.name.hasSuffix(".ipa") }
                .flatMap { URL(string: $0.browser_download_url) }
            latest = Release(version: version,
                             ipa: ipa,
                             page: w.html_url.flatMap(URL.init(string:)),
                             notes: (w.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Hand the .ipa to the sideloader that can install it; fall back to the release page.
    func install() {
        guard let rel = latest else { return }
        guard let ipa = rel.ipa else {
            if let page = rel.page { UIApplication.shared.open(page) }
            return
        }
        // These installers all take the ipa URL raw (that's the documented form —
        // percent-encoding the whole thing makes them choke). Whichever is
        // installed answers first; if none is, the ipa just downloads.
        // LiveContainer leads because that's what this app is run under.
        let raw = ipa.absoluteString
        let handoffs = ["livecontainer://install?url=\(raw)",
                        "altstore://install?url=\(raw)",
                        "sidestore://install?url=\(raw)"].compactMap(URL.init(string:))
        open(handoffs, fallback: ipa)
    }

    private func open(_ candidates: [URL], fallback: URL) {
        guard let next = candidates.first else { UIApplication.shared.open(fallback); return }
        UIApplication.shared.open(next, options: [:]) { ok in
            if !ok { Task { @MainActor in self.open(Array(candidates.dropFirst()), fallback: fallback) } }
        }
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }
    var buildNumber: String { infoDictionary?["CFBundleVersion"] as? String ?? "0" }
}

struct UpdateSettings: View {
    @StateObject private var up = Updater.shared

    var body: some View {
        List {
            Section {
                LabeledContent("Установлена", value: "\(up.current) (\(up.currentBuild))")
                // If the bundle disagrees with the stamped binary, say so out loud —
                // that mismatch is what made "installed version" nonsense before.
                if !BuildInfo.isPlaceholder, Bundle.main.shortVersion != BuildInfo.version {
                    LabeledContent("Info.plist сообщает", value: Bundle.main.shortVersion)
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if up.checking {
                    HStack { ProgressView(); Text("Проверяю…").foregroundStyle(.secondary) }
                } else {
                    Button("Проверить обновления") { Task { await up.check() } }
                }
            }

            if let rel = up.latest {
                Section("Доступна \(rel.version)") {
                    if !rel.notes.isEmpty {
                        Text(rel.notes).font(.footnote).foregroundStyle(.secondary)
                    }
                    Button { up.install() } label: {
                        Label("Обновить", systemImage: "arrow.down.circle.fill")
                    }
                    if let ipa = rel.ipa {
                        Link("Скачать .ipa вручную", destination: ipa).font(.footnote)
                    }
                    if let page = rel.page {
                        Link("Открыть на GitHub", destination: page).font(.footnote)
                    }
                }
            } else if up.checkedOnce, up.error == nil {
                Section { Label("Установлена последняя версия", systemImage: "checkmark.circle") }
            }

            if let e = up.error {
                Section { Text(e).font(.footnote).foregroundStyle(.red) }
            }

            Section {
                Text("Кнопка отдаёт .ipa установщику: LiveContainer, AltStore или SideStore. LiveContainer при этом попросит себя перезапустить — так и должно быть: приложение работает внутри него, и поставить обновление он может, только выгрузив его. После перезапуска установка продолжится.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Обновление")
        .task { if !up.checkedOnce { await up.check() } }
    }
}
