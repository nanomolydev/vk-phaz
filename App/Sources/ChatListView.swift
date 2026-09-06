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
                Circle().fill(TG.onlineDot)
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
            ScrollViewReader { proxy in
            List {
                ForEach(shown) { row in
                    ZStack(alignment: .leading) {
                        // NavigationLink insists on a disclosure chevron; the
                        // reference has none, so keep the link invisible.
                        NavigationLink(value: row) { EmptyView() }.opacity(0)
                        rowView(row)
                    }
                        .id(row.peerId)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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
            .scrollEdgeEffectStyle(nil, for: .all)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 8) {
                    searchField
                    FolderStrip(folders: folders, selected: $selectedFolder,
                                onAdd: { editingFolder = ChatFolder(name: "", peerIds: []) },
                                onEdit: { editingFolder = $0 })
                }
                .padding(.top, 2)
                .padding(.bottom, 2)
                .background(Color(.systemBackground))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(TG.separator).frame(height: 0.5)
                }
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
            .task {
                await load()
                // Park the list mid-scroll for screenshots: rows only sit behind
                // the header and tab bar once something has scrolled under them.
                if PreviewMode.isOn, shown.count > 8 {
                    proxy.scrollTo(shown[6].peerId, anchor: .top)
                }
            }
            .onChange(of: live.bump) { _ in Task { await load() } }
            }
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
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(TG.searchBar, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
    }

    // Geometry taken from ChatListItem.swift in Telegram-iOS: 60pt avatar,
    // 16pt left edge inset + 8pt gap (so text and the separator start at 84),
    // semibold 16 title, regular 15 preview, regular 14 date, avatar centred
    // in the row.
    private func rowView(_ row: ChatRow) -> some View {
        HStack(spacing: 8) {
            AvatarView(url: row.avatar, name: row.title, id: row.peerId,
                       size: 60, online: row.online)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(row.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TG.title)
                        .lineLimit(1)
                    if Mutes.has(row.peerId) {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 12)).foregroundStyle(TG.muteIcon)
                    }
                    Spacer(minLength: 4)
                    Text(shortTime(row.date))
                        .font(.system(size: 14)).foregroundStyle(TG.dateText)
                }
                HStack(spacing: 6) {
                    Text(row.subtitle)
                        .font(.system(size: 15)).foregroundStyle(TG.messageText)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if row.unread > 0 {
                        Text(row.unread > 999 ? "999+" : "\(row.unread)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .frame(minWidth: 20)
                            .background(Mutes.has(row.peerId) ? TG.badgeInactive : TG.badgeActive,
                                        in: Capsule())
                    } else if Pins.has(row.peerId) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12)).foregroundStyle(TG.pinnedBadge)
                            .rotationEffect(.degrees(45))
                    }
                }
            }
        }
        .frame(height: 76)
        .overlay(alignment: .bottom) {
            Rectangle().fill(TG.separator)
                .frame(height: 0.5)
                .padding(.leading, 68)
        }
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
        catch let e as VKError { error = PreviewMode.isOn ? nil : e.error_msg }
        catch { self.error = error.localizedDescription }
    }
}
