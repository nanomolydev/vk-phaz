import SwiftUI

struct AvatarView: View {
    let url: URL?
    let name: String
    let id: Int
    var size: CGFloat = 50
    var online = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle().fill(avatarTint(for: id).gradient)
                    .overlay(Text(initials(name))
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(.white))
                if url != nil { CachedImage(url: url, placeholder: .clear) }
            }
            .frame(width: size, height: size).clipShape(Circle())
            if online {
                Circle().fill(.green)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: size * 0.06))
            }
        }
    }
}

struct ChatListView: View {
    let vk: VK
    let ownId: Int
    @EnvironmentObject var live: LiveUpdates
    @State private var rows: [ChatRow] = []
    @State private var query = ""
    @State private var error: String?
    @State private var showOwnProfile = false
    @State private var pinsTick = 0
    @State private var folders: [ChatFolder] = FolderStore.load()
    @State private var selectedFolder: UUID?
    @State private var editingFolder: ChatFolder?

    private var shown: [ChatRow] {
        _ = pinsTick
        let pins = Pins.get()
        var f = query.isEmpty ? rows
              : rows.filter { $0.title.localizedCaseInsensitiveContains(query) }
        if let id = selectedFolder, let folder = folders.first(where: { $0.id == id }) {
            f = f.filter { folder.peerIds.contains($0.peerId) }
        }
        return f.sorted { a, b in
            let pa = pins.contains(a.peerId), pb = pins.contains(b.peerId)
            if pa != pb { return pa }
            return a.date > b.date
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(shown) { row in
                    NavigationLink(value: row) { rowView(row) }
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading) {
                            Button {
                                Pins.toggle(row.peerId); pinsTick += 1
                            } label: {
                                Label(Pins.has(row.peerId) ? "Открепить" : "Закрепить",
                                      systemImage: "pin")
                            }.tint(.orange)
                        }
                }
            }
            .listStyle(.plain)
            // Both the List background and each row's own background are opaque
            // by default — together they were the white slab showing through the
            // tab bar instead of the chats.
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 8) {
                    searchField
                    FolderStrip(folders: folders, selected: $selectedFolder,
                                onAdd: { editingFolder = ChatFolder(name: "", peerIds: []) },
                                onEdit: { editingFolder = $0 })
                }
                .padding(.bottom, 8)
                // This header does need a backdrop — rows scroll underneath it,
                // and without one the chat titles read straight through the
                // search field and the folder chips.
                .background(.bar)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Centred between the profile and bookmark buttons.
                ToolbarItem(placement: .principal) { Text("Чаты").font(.headline) }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showOwnProfile = true } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: ChatRow(peerId: ownId, title: "Избранное",
                                                  subtitle: "", date: 0, avatar: nil, online: false)) {
                        Image(systemName: "bookmark.circle")
                    }
                }
            }
            .navigationDestination(for: ChatRow.self) { row in
                ChatView(vk: vk, peerId: row.peerId, title: row.title, ownId: ownId)
            }
            .sheet(isPresented: $showOwnProfile) {
                NavigationStack { ProfileView(vk: vk, userId: ownId, ownId: ownId) }
            }
            .sheet(item: $editingFolder) { f in
                FolderEditor(rows: rows, folder: f,
                             onSave: { saved in
                                 if let i = folders.firstIndex(where: { $0.id == saved.id }) {
                                     folders[i] = saved
                                 } else {
                                     folders.append(saved)
                                 }
                                 FolderStore.save(folders)
                             },
                             onDelete: folders.contains(where: { $0.id == f.id }) ? {
                                 folders.removeAll { $0.id == f.id }
                                 if selectedFolder == f.id { selectedFolder = nil }
                                 FolderStore.save(folders)
                             } : nil)
            }
            .overlay { if rows.isEmpty, let error { Text(error).foregroundStyle(.secondary).padding() } }
            .refreshable { await load() }
            .task { await load() }
            .onChange(of: live.bump) { _ in Task { await load() } }
        }
    }

    // Own field instead of .searchable: the system one left-aligns its text and
    // tints the glyph, and neither can be overridden.
    private var searchField: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Поиск чатов", text: $query)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .fixedSize()
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(.quaternary, in: Capsule())
        .padding(.horizontal, 12)
    }

    private func rowView(_ row: ChatRow) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: row.avatar, name: row.title, id: row.peerId, online: row.online)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title).font(.body.weight(.semibold)).lineLimit(1)
                Text(row.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(shortTime(row.date)).font(.caption).foregroundStyle(.secondary)
                if Pins.has(row.peerId) {
                    Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        // Paint the last known list first — the network call follows and replaces it.
        if rows.isEmpty, let cached = DiskCache.load([ChatRow].self, "chats-\(ownId)") {
            rows = cached
        }
        do {
            rows = try await vk.conversations()
            DiskCache.save(rows, as: "chats-\(ownId)")
            live.setNames(Dictionary(rows.map { ($0.peerId, $0.title) }, uniquingKeysWith: { a, _ in a }))
            error = nil
        }
        catch let e as VKError { error = e.error_msg }
        catch { self.error = error.localizedDescription }
    }
}
