import SwiftUI

// Telegram-shaped profile: large avatar header, a row of square action buttons,
// an info block, then segmented tabs. VK's wall fills the Записи tab — that's
// the content the old profile was missing entirely.
struct ProfileView: View {
    let vk: VK
    let userId: Int
    let ownId: Int

    enum Tab: String, CaseIterable { case posts = "Записи", photos = "Фото", friends = "Друзья" }

    @State private var profile: Profile?
    @State private var friends: [Profile] = []
    @State private var posts: [WallPost] = []
    @State private var photos: [URL] = []
    @State private var tab: Tab = .posts
    @State private var loading = true
    @State private var error: String?
    @State private var viewer: IdURL?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if let p = profile {
                    header(p)
                    infoBlock(p)
                    Section {
                        content(p)
                    } header: {
                        tabBar
                    }
                } else if loading {
                    ProgressView().padding(.top, 80)
                } else if let error {
                    Text(error).foregroundStyle(.secondary).padding(.top, 80)
                }
            }
        }
        .scrollEdgeEffectStyle(nil, for: .all)
        .navigationTitle(profile?.fullName ?? (userId == ownId ? "Мой профиль" : "Профиль"))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $viewer) { PhotoViewer(url: $0.url) }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: header

    private func header(_ p: Profile) -> some View {
        VStack(spacing: 10) {
            AvatarView(url: p.avatar, name: p.fullName, id: p.id, size: 96)
                .onTapGesture { if let a = p.avatar { viewer = IdURL(url: a) } }
            Text(p.fullName).font(.title2.bold())
            let seen = lastSeenText(online: p.online == 1, ts: p.last_seen?.time)
            if !seen.isEmpty {
                Text(seen).font(.subheadline)
                    .foregroundStyle(p.online == 1 ? Color.accentColor : .secondary)
            }
            actionRow(p)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8).padding(.bottom, 14)
    }

    private func actionRow(_ p: Profile) -> some View {
        HStack(spacing: 10) {
            if userId != ownId {
                NavigationLink {
                    ChatView(vk: vk, peerId: userId, title: p.fullName, ownId: ownId)
                } label: { actionTile("Написать", "message.fill") }
                .buttonStyle(.plain)

                Button {
                    Mutes.toggle(userId)
                } label: {
                    actionTile(Mutes.has(userId) ? "Включить" : "Выключить",
                               Mutes.has(userId) ? "bell.slash.fill" : "bell.fill")
                }
                .buttonStyle(.plain)
            }
            Link(destination: URL(string: "https://vk.com/\(p.screen_name ?? "id\(p.id)")")!) {
                actionTile("В VK", "safari.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.top, 6)
    }

    private func actionTile(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption2)
        }
        .foregroundStyle(Color.accentColor)
        .frame(maxWidth: .infinity).frame(height: 62)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private func infoBlock(_ p: Profile) -> some View {
        VStack(spacing: 0) {
            if let st = p.status, !st.isEmpty { infoRow("О себе", st, "quote.bubble") }
            if let s = p.screen_name { infoRow("Ссылка", "@\(s)", "at") }
            if let c = p.city { infoRow("Город", c.title, "mappin.and.ellipse") }
        }
        .padding(.horizontal, 16)
    }

    private func infoRow(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.body)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: tabs

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    VStack(spacing: 6) {
                        Text(t.rawValue)
                            .font(.subheadline.weight(tab == t ? .semibold : .regular))
                            .foregroundStyle(tab == t ? Color.accentColor : .secondary)
                        Rectangle().fill(tab == t ? Color.accentColor : .clear).frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .background(.bar)
    }

    @ViewBuilder private func content(_ p: Profile) -> some View {
        switch tab {
        case .posts:
            if posts.isEmpty { empty(p, "Записей нет") }
            else { ForEach(posts) { postCard($0) } }
        case .photos:
            if photos.isEmpty { empty(p, "Фотографий нет") }
            else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
                          spacing: 2) {
                    ForEach(photos, id: \.self) { u in
                        CachedImage(url: u)
                            .frame(height: 120).clipped()
                            .onTapGesture { viewer = IdURL(url: u) }
                    }
                }
                .padding(.top, 2)
            }
        case .friends:
            if friends.isEmpty { empty(p, "Список пуст") }
            else {
                ForEach(friends) { f in
                    NavigationLink { ProfileView(vk: vk, userId: f.id, ownId: ownId) } label: {
                        HStack(spacing: 12) {
                            AvatarView(url: f.avatar, name: f.fullName, id: f.id, size: 44,
                                       online: f.online == 1)
                            Text(f.fullName).foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func empty(_ p: Profile, _ text: String) -> some View {
        Text(p.is_closed == true && userId != ownId ? "Профиль закрыт" : text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private func postCard(_ post: WallPost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !post.displayText.isEmpty {
                Text(post.displayText).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(post.photos, id: \.self) { u in
                CachedImage(url: u)
                    .frame(maxWidth: .infinity).frame(height: 220).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { viewer = IdURL(url: u) }
            }
            HStack(spacing: 16) {
                Label("\(post.likes?.count ?? 0)", systemImage: "heart")
                Label("\(post.comments?.count ?? 0)", systemImage: "bubble.right")
                if let v = post.views?.count { Label("\(v)", systemImage: "eye") }
                Spacer()
                Text(shortTime(post.date))
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 16) }
    }

    private func load() async {
        loading = true
        do {
            let p = try await vk.user(id: userId == ownId ? nil : userId)
            profile = p
            error = nil
        } catch let e as VKError { error = e.error_msg }
        catch { self.error = error.localizedDescription }

        // Wall and photos are best-effort: a closed profile just leaves them empty.
        async let w = try? await vk.wall(ownerId: userId)
        async let ph = try? await vk.photos(ownerId: userId)
        async let fr = try? await vk.friends(userId: userId)
        posts = await w ?? []
        photos = await ph ?? []
        friends = await fr ?? []
        loading = false
    }
}
