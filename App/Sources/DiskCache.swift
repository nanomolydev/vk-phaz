import Foundation

// Last-known chats and messages, so a screen paints instantly instead of
// showing nothing until the network answers. Caches directory: the system may
// evict it, and everything here is re-fetchable.
// ponytail: plain JSON files, no database — a few hundred rows per chat.
enum DiskCache {
    private static let dir: URL? = {
        guard let base = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: true) else { return nil }
        let d = base.appendingPathComponent("vk", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    static func save<T: Encodable>(_ value: T, as name: String) {
        guard let url = dir?.appendingPathComponent(name + ".json"),
              let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let url = dir?.appendingPathComponent(name + ".json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
