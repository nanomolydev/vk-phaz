import SwiftUI

// Friends list as its own tab. Tapping one opens the chat with them.
struct ContactsView: View {
    let vk: VK
    let ownId: Int

    @State private var people: [Profile] = []
    @State private var query = ""
    @State private var error: String?

    private var shown: [Profile] {
        let base = query.isEmpty ? people
            : people.filter { $0.fullName.localizedCaseInsensitiveContains(query) }
        return base.sorted { $0.fullName < $1.fullName }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(shown) { p in
                    NavigationLink(value: ChatRow(peerId: p.id, title: p.fullName, subtitle: "",
                                                  date: 0, avatar: p.avatar, online: p.online == 1)) {
                        HStack(spacing: 12) {
                            AvatarView(url: p.avatar, name: p.fullName, id: p.id, size: 44,
                                       online: p.online == 1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.fullName).font(.body.weight(.medium))
                                Text(lastSeenText(online: p.online == 1, ts: p.last_seen?.time))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .searchable(text: $query, prompt: "Поиск контактов")
            .navigationTitle("Контакты")
            .navigationDestination(for: ChatRow.self) { row in
                ChatView(vk: vk, peerId: row.peerId, title: row.title, ownId: ownId)
            }
            .overlay { if people.isEmpty, let error { Text(error).foregroundStyle(.secondary) } }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        // Cached first so the tab isn't blank on open.
        if people.isEmpty, let c = DiskCache.load([Profile].self, "friends-\(ownId)") { people = c }
        do {
            people = try await vk.friends(userId: ownId)
            DiskCache.save(people, as: "friends-\(ownId)")
            error = nil
        }
        catch let e as VKError { error = e.error_msg }
        catch { self.error = error.localizedDescription }
    }
}
