import Foundation

// MARK: - Wire models (only fields we use)

struct VKError: Decodable, Error {
    let error_code: Int
    let error_msg: String
    var captcha_sid: String? = nil
    var captcha_img: String? = nil
}
struct VKResponse<T: Decodable>: Decodable { let response: T?; let error: VKError? }
struct VKIgnored: Decodable {}  // for responses whose body we don't need

struct Profile: Codable, Identifiable {
    let id: Int
    let first_name: String
    let last_name: String
    var photo_100: String?
    var photo_200: String?
    var online: Int?
    var last_seen: LastSeen?
    var status: String?
    var screen_name: String?
    var city: City?
    var is_closed: Bool?
    struct LastSeen: Codable { let time: Int }
    struct City: Codable { let title: String }
    var fullName: String { "\(first_name) \(last_name)" }
    var avatar: URL? { (photo_200 ?? photo_100).flatMap(URL.init(string:)) }
}

struct VKGroup: Codable {
    let id: Int
    let name: String
    var photo_100: String?
    var photo_200: String?
    var screen_name: String?
}

struct AttachmentImage: Codable { let url: String; let width: Int }
struct Attachment: Codable {
    let type: String
    let sticker: Sticker?
    let photo: Photo?
    let doc: Doc?
    let audio_message: AudioMessage?
    struct Sticker: Codable { let images: [AttachmentImage] }
    struct Photo: Codable { let sizes: [AttachmentImage] }
    struct Doc: Codable { let title: String?; let url: String?; let ext: String?; let size: Int? }
    struct AudioMessage: Codable { let duration: Int?; let link_mp3: String?; let link_ogg: String? }
}

struct Msg: Codable, Identifiable {
    let id: Int
    let from_id: Int
    let text: String
    let date: Int
    var conversation_message_id: Int?
    var attachments: [Attachment]?
    var reply_message: Reply?
    var fwd_messages: [Reply]?
    var reactions: [Reaction]?
    struct Reply: Codable {
        let from_id: Int
        let text: String
        enum K: String, CodingKey { case from_id, text }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            from_id = try c.decodeIfPresent(Int.self, forKey: .from_id) ?? 0
            text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        }
    }
    struct Reaction: Codable { let reaction_id: Int; let count: Int }

    enum K: String, CodingKey {
        case id, from_id, text, date, conversation_message_id
        case attachments, reply_message, fwd_messages, reactions
    }

    // Service messages, pinned payloads and some forwards omit fields VK's docs
    // call mandatory. Treating them as required threw, and one such message
    // took the whole chat list down with it.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        from_id = try c.decodeIfPresent(Int.self, forKey: .from_id) ?? 0
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        date = try c.decodeIfPresent(Int.self, forKey: .date) ?? 0
        conversation_message_id = try c.decodeIfPresent(Int.self, forKey: .conversation_message_id)
        attachments = try c.decodeIfPresent(Lossy<Attachment>.self, forKey: .attachments)?.wrappedValue
        reply_message = try? c.decodeIfPresent(Reply.self, forKey: .reply_message)
        fwd_messages = try c.decodeIfPresent(Lossy<Reply>.self, forKey: .fwd_messages)?.wrappedValue
        reactions = try c.decodeIfPresent(Lossy<Reaction>.self, forKey: .reactions)?.wrappedValue
    }

    var stickerURL: URL? {
        guard let img = (attachments ?? []).first(where: { $0.type == "sticker" })?
            .sticker?.images.max(by: { $0.width < $1.width }) else { return nil }
        return URL(string: img.url)
    }
    var photoURL: URL? {
        guard let img = (attachments ?? []).first(where: { $0.type == "photo" })?
            .photo?.sizes.max(by: { $0.width < $1.width }) else { return nil }
        return URL(string: img.url)
    }
    var doc: Attachment.Doc? { (attachments ?? []).first(where: { $0.type == "doc" })?.doc }
    var voice: Attachment.AudioMessage? {
        (attachments ?? []).first(where: { $0.type == "audio_message" })?.audio_message
    }

    // A human preview for the chat list when text is empty.
    var preview: String {
        if !text.isEmpty { return text }
        if stickerURL != nil { return "🩷 Стикер" }
        if photoURL != nil { return "🖼 Фото" }
        if voice != nil { return "🎤 Голосовое" }
        if let d = doc { return "📎 " + (d.title ?? "Файл") }
        if fwd_messages?.isEmpty == false { return "↪️ Пересланное" }
        return ""
    }
}

// VK's shapes vary per message kind, and a single unexpected element used to
// fail the whole decode — one odd conversation blanked the entire chat list.
// Decode elements individually and drop only the ones that don't fit.
@propertyWrapper
struct Lossy<T: Decodable>: Decodable {
    var wrappedValue: [T]

    private struct Element: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    init(from decoder: Decoder) throws {
        // Decoding as Element never throws, so the container always advances.
        wrappedValue = try [Element](from: decoder).compactMap(\.value)
    }

    init(wrappedValue: [T]) { self.wrappedValue = wrappedValue }
}

extension KeyedDecodingContainer {
    /// A missing or null list is an empty list, not a failure.
    func decode<T>(_ type: Lossy<T>.Type, forKey key: Key) throws -> Lossy<T> {
        try decodeIfPresent(type, forKey: key) ?? Lossy(wrappedValue: [])
    }
}

struct HistoryResponse: Decodable {
    let count: Int?
    @Lossy var items: [Msg]
    @Lossy var profiles: [Profile]
    @Lossy var groups: [VKGroup]
}

struct Conversations: Decodable {
    @Lossy var items: [ConvItem]
    @Lossy var profiles: [Profile]
    @Lossy var groups: [VKGroup]
}
struct ConvItem: Decodable { let conversation: Conv; let last_message: Msg? }
struct Conv: Decodable {
    let peer: Peer
    let chat_settings: ChatSettings?
    let push_settings: PushSettings?
    struct PushSettings: Decodable {
        let disabled_until: Int?
        let disabled_forever: Bool?
        /// VK uses -1 for "forever"; otherwise a unix time the mute runs to.
        var isMuted: Bool {
            if disabled_forever == true { return true }
            guard let u = disabled_until else { return false }
            return u == -1 || Double(u) > Date().timeIntervalSince1970
        }
    }
    struct ChatSettings: Decodable {
        let title: String?
        let photo: Ph?
        struct Ph: Decodable { let photo_100: String? }
    }
}
struct Peer: Decodable { let id: Int; let type: String }

struct FriendsResponse: Decodable { let count: Int; let items: [Profile] }
struct LongPollServer: Decodable { let server: String; let key: String; let ts: Int }

struct StickerItem: Decodable, Identifiable {
    let sticker_id: Int
    let images: [AttachmentImage]?
    var id: Int { sticker_id }
    var url: URL? {
        guard let img = (images ?? []).max(by: { $0.width < $1.width }) else { return nil }
        return URL(string: img.url)
    }
}
struct StoreProducts: Decodable {
    let items: [Product]
    struct Product: Decodable { let id: Int?; let title: String?; let stickers: [StickerItem]? }
}
struct StickerPack: Identifiable {
    let id: Int
    let title: String
    let stickers: [StickerItem]
}

// A resolved chat-list row.
struct ChatRow: Identifiable, Hashable, Codable {
    let peerId: Int
    let title: String
    let subtitle: String
    let date: Int
    let avatar: URL?
    let online: Bool
    var isChat: Bool { peerId >= 2_000_000_000 }
    var id: Int { peerId }
    static func == (a: ChatRow, b: ChatRow) -> Bool { a.peerId == b.peerId }
    func hash(into h: inout Hasher) { h.combine(peerId) }
}

// A message plus its resolved sender (for group chats / replies).
struct ChatMessage: Identifiable, Codable {
    let msg: Msg
    let senderName: String
    let senderAvatar: URL?
    let replyAuthor: String?
    var id: Int { msg.id }
}

// MARK: - API client

struct VK {
    static let base = "https://api.vk.com/method/"
    static let version = "5.199"
    let token: String

    // Build a name/avatar directory from extended profiles + groups.
    private func directory(_ profiles: [Profile]?, _ groups: [VKGroup]?) -> (names: [Int: String], avatars: [Int: URL]) {
        var names: [Int: String] = [:], avatars: [Int: URL] = [:]
        for p in profiles ?? [] { names[p.id] = p.fullName; avatars[p.id] = p.avatar }
        for g in groups ?? [] {
            names[-g.id] = g.name
            avatars[-g.id] = (g.photo_100).flatMap(URL.init(string:))
        }
        return (names, avatars)
    }

    private func describe(_ e: DecodingError) -> String {
        func path(_ ctx: DecodingError.Context) -> String {
            ctx.codingPath.map(\.stringValue).joined(separator: ".")
        }
        switch e {
        case .keyNotFound(let k, let ctx): return "нет поля '\(k.stringValue)' в \(path(ctx))"
        case .valueNotFound(_, let ctx): return "пустое значение в \(path(ctx))"
        case .typeMismatch(let t, let ctx): return "\(path(ctx)) — ожидался \(t)"
        case .dataCorrupted(let ctx): return "испорченный ответ \(path(ctx))"
        @unknown default: return e.localizedDescription
        }
    }

    private func call<T: Decodable>(_ method: String, _ params: [String: String], retries: Int = 1) async throws -> T {
        var comps = URLComponents()
        var q = params
        q["access_token"] = token
        q["v"] = VK.version
        comps.queryItems = q.map { URLQueryItem(name: $0.key, value: $0.value) }
        var req = URLRequest(url: URL(string: VK.base + method)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = comps.percentEncodedQuery?.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        let wrapped: VKResponse<T>
        do { wrapped = try JSONDecoder().decode(VKResponse<T>.self, from: data) }
        catch let e as DecodingError {
            // "The data couldn't be read because it is missing" names nothing.
            // Say which method and which field, so a VK shape change is one read.
            throw VKError(error_code: -2, error_msg: "\(method): \(describe(e))")
        }
        if let e = wrapped.error {
            // error 14 = captcha: show it, get the user's answer, retry once with the key.
            if e.error_code == 14, retries > 0, let sid = e.captcha_sid, let img = e.captcha_img {
                if let key = await CaptchaCenter.shared.request(sid: sid, imageURL: img) {
                    var p = params; p["captcha_sid"] = sid; p["captcha_key"] = key
                    return try await call(method, p, retries: retries - 1)
                }
            }
            throw e
        }
        guard let r = wrapped.response else { throw VKError(error_code: -1, error_msg: "Пустой ответ") }
        return r
    }

    // MARK: Chats

    func conversations() async throws -> [ChatRow] {
        let c: Conversations = try await call("messages.getConversations",
            ["extended": "1", "count": "100", "fields": "photo_100,online"])
        let (names, avatars) = directory(c.profiles, c.groups)
        Mutes.merge(fromVK: Set(c.items.filter { $0.conversation.push_settings?.isMuted == true }
                                        .map { $0.conversation.peer.id }))
        let onlineIds = Set((c.profiles ?? []).filter { $0.online == 1 }.map { $0.id })
        return c.items.map { item in
            let peer = item.conversation.peer
            let title: String
            let avatar: URL?
            switch peer.type {
            case "user", "group":
                title = names[peer.id] ?? "id\(peer.id)"
                avatar = avatars[peer.id]
            default:
                title = item.conversation.chat_settings?.title ?? "Беседа"
                avatar = item.conversation.chat_settings?.photo?.photo_100.flatMap(URL.init(string:))
            }
            return ChatRow(peerId: peer.id, title: title,
                           subtitle: item.last_message?.preview ?? "",
                           date: item.last_message?.date ?? 0,
                           avatar: avatar, online: onlineIds.contains(peer.id))
        }
    }

    func history(peerId: Int) async throws -> [ChatMessage] {
        let h: HistoryResponse = try await call("messages.getHistory",
            ["peer_id": String(peerId), "count": "80", "extended": "1", "fields": "photo_100"])
        return resolve(h.items.reversed(), h.profiles, h.groups)
    }

    // For AI summarization: a page of history, oldest-first, at an offset from the newest.
    func historyPage(peerId: Int, offset: Int, count: Int = 200) async throws -> [ChatMessage] {
        let h: HistoryResponse = try await call("messages.getHistory",
            ["peer_id": String(peerId), "count": String(count), "offset": String(offset),
             "extended": "1", "fields": "photo_100"])
        return resolve(h.items.reversed(), h.profiles, h.groups)
    }

    func historyTotal(peerId: Int) async throws -> Int {
        let h: HistoryResponse = try await call("messages.getHistory",
            ["peer_id": String(peerId), "count": "1"])
        return h.count ?? 0
    }

    // A window of messages centered on a specific message (for in-chat search jump).
    func historyAround(peerId: Int, messageId: Int, count: Int = 40) async throws -> [ChatMessage] {
        let h: HistoryResponse = try await call("messages.getHistory",
            ["peer_id": String(peerId), "start_message_id": String(messageId),
             "offset": String(-count / 2), "count": String(count),
             "extended": "1", "fields": "photo_100"])
        return resolve(h.items.reversed(), h.profiles, h.groups)
    }

    // Search returns matching message ids, oldest-first, for stepping through in the chat.
    func searchIds(peerId: Int, query: String) async throws -> [Int] {
        let h: HistoryResponse = try await call("messages.search",
            ["peer_id": String(peerId), "q": query, "count": "200"])
        return h.items.map { $0.id }.sorted()
    }

    func search(peerId: Int, query: String, before: Date? = nil) async throws -> [ChatMessage] {
        var p = ["peer_id": String(peerId), "q": query, "count": "100",
                 "extended": "1", "fields": "photo_100"]
        if let before {
            let f = DateFormatter()
            f.dateFormat = "ddMMyyyy"
            p["date"] = f.string(from: before)   // VK: только сообщения до этой даты
        }
        let h: HistoryResponse = try await call("messages.search", p)
        return resolve(h.items, h.profiles, h.groups)
    }

    private func resolve(_ items: [Msg], _ profiles: [Profile]?, _ groups: [VKGroup]?) -> [ChatMessage] {
        let (names, avatars) = directory(profiles, groups)
        return items.map { m in
            ChatMessage(msg: m,
                        senderName: names[m.from_id] ?? "id\(m.from_id)",
                        senderAvatar: avatars[m.from_id],
                        replyAuthor: m.reply_message.flatMap { names[$0.from_id] })
        }
    }

    func send(peerId: Int, text: String, replyTo: Int? = nil, attachment: String? = nil) async throws {
        var p = ["peer_id": String(peerId), "message": text,
                 "random_id": String(Int32.random(in: 1...Int32.max))]
        if let replyTo { p["reply_to"] = String(replyTo) }
        if let attachment { p["attachment"] = attachment }
        let _: Int = try await call("messages.send", p)
    }

    func sendSticker(peerId: Int, stickerId: Int) async throws {
        let _: Int = try await call("messages.send",
            ["peer_id": String(peerId), "sticker_id": String(stickerId),
             "random_id": String(Int32.random(in: 1...Int32.max))])
    }

    func sendReaction(peerId: Int, cmid: Int, reactionId: Int) async throws {
        let _: Int = try await call("messages.sendReaction",
            ["peer_id": String(peerId), "cmid": String(cmid), "reaction_id": String(reactionId)])
    }

    func deleteMessages(peerId: Int, cmids: [Int], forAll: Bool) async throws {
        let p = ["peer_id": String(peerId),
                 "cmids": cmids.map(String.init).joined(separator: ","),
                 "delete_for_all": forAll ? "1" : "0"]
        let _: VKIgnored = try await call("messages.delete", p)
    }

    func deleteReaction(peerId: Int, cmid: Int) async throws {
        let _: VKIgnored = try await call("messages.deleteReaction",
            ["peer_id": String(peerId), "cmid": String(cmid)])
    }

    // Last outgoing message id the peer has read. A message id <= this is "read" (✓✓).
    func outRead(peerId: Int) async throws -> Int {
        struct R: Decodable { let items: [Item]?; struct Item: Decodable { let out_read: Int? } }
        let r: R = try await call("messages.getConversationsById", ["peer_ids": String(peerId)])
        return r.items?.first?.out_read ?? 0
    }

    func forward(peerId: Int, messageIds: [Int]) async throws {
        let _: Int = try await call("messages.send",
            ["peer_id": String(peerId),
             "forward_messages": messageIds.map(String.init).joined(separator: ","),
             "random_id": String(Int32.random(in: 1...Int32.max))])
    }

    func editMessage(peerId: Int, cmid: Int, text: String) async throws {
        let _: Int = try await call("messages.edit",
            ["peer_id": String(peerId),
             "conversation_message_id": String(cmid),
             "message": text,
             "keep_forward_messages": "1",
             "keep_snippets": "1"])
    }

    func pinMessage(peerId: Int, cmid: Int) async throws {
        let _: VKIgnored = try await call("messages.pin",
            ["peer_id": String(peerId), "conversation_message_id": String(cmid)])
    }

    func stickers() async throws -> [StickerItem] {
        try await stickerPacks().flatMap { $0.stickers }
    }

    func stickerPacks() async throws -> [StickerPack] {
        let r: StoreProducts = try await call("store.getProducts",
            ["type": "stickers", "filters": "purchased,active", "extended": "1"])
        return r.items.enumerated().compactMap { i, prod in
            let items = prod.stickers ?? []
            guard !items.isEmpty else { return nil }
            return StickerPack(id: prod.id ?? i, title: prod.title ?? "Стикеры", stickers: items)
        }
    }

    func setActivity(peerId: Int) async {
        let _: Int? = try? await call("messages.setActivity",
            ["peer_id": String(peerId), "type": "typing"])
    }

    // MARK: Users & friends

    func user(id: Int?) async throws -> Profile {
        var p = ["fields": "photo_200,photo_100,online,last_seen,status,screen_name,city,is_closed"]
        if let id { p["user_ids"] = String(id) }
        let arr: [Profile] = try await call("users.get", p)
        guard let u = arr.first else { throw VKError(error_code: -1, error_msg: "Нет пользователя") }
        return u
    }

    func friends(userId: Int) async throws -> [Profile] {
        let r: FriendsResponse = try await call("friends.get",
            ["user_id": String(userId), "count": "1000", "fields": "photo_100,online"])
        return r.items
    }

    // MARK: Uploads

    func uploadPhoto(peerId: Int, data: Data) async throws -> String {
        struct Up: Decodable { let upload_url: String }
        let up: Up = try await call("photos.getMessagesUploadServer", ["peer_id": String(peerId)])
        struct Uploaded: Decodable { let server: Int; let photo: String; let hash: String }
        let u: Uploaded = try await multipart(up.upload_url, field: "photo",
                                              filename: "image.jpg", mime: "image/jpeg", data: data)
        struct Saved: Decodable { let owner_id: Int; let id: Int }
        let saved: [Saved] = try await call("photos.saveMessagesPhoto",
            ["server": String(u.server), "photo": u.photo, "hash": u.hash])
        guard let s = saved.first else { throw VKError(error_code: -1, error_msg: "upload failed") }
        return "photo\(s.owner_id)_\(s.id)"
    }

    func uploadDoc(peerId: Int, data: Data, name: String) async throws -> String {
        try await uploadDocTyped(peerId: peerId, data: data, name: name, type: "doc",
                                 field: "file", mime: "application/octet-stream")
    }

    // VK voice message: upload as an audio_message doc (m4a). May render as a file if VK rejects the codec.
    func uploadVoice(peerId: Int, data: Data) async throws -> String {
        try await uploadDocTyped(peerId: peerId, data: data, name: "voice.m4a",
                                 type: "audio_message", field: "file", mime: "audio/m4a")
    }

    private func uploadDocTyped(peerId: Int, data: Data, name: String, type: String,
                                field: String, mime: String) async throws -> String {
        struct Up: Decodable { let upload_url: String }
        let up: Up = try await call("docs.getMessagesUploadServer",
            ["peer_id": String(peerId), "type": type])
        struct Uploaded: Decodable { let file: String }
        let u: Uploaded = try await multipart(up.upload_url, field: field,
                                              filename: name, mime: mime, data: data)
        struct SaveResp: Decodable {
            let type: String?
            let doc: D?
            let audio_message: D?
            struct D: Decodable { let owner_id: Int; let id: Int }
        }
        let saved: SaveResp = try await call("docs.save", ["file": u.file])
        if let am = saved.audio_message { return "doc\(am.owner_id)_\(am.id)" }
        if let d = saved.doc { return "doc\(d.owner_id)_\(d.id)" }
        throw VKError(error_code: -1, error_msg: "upload failed")
    }

    private func multipart<T: Decodable>(_ urlString: String, field: String, filename: String,
                                         mime: String, data: Data) async throws -> T {
        let boundary = "----vkphaz\(Int32.random(in: 0...Int32.max))"
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mime)\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")
        req.httpBody = body
        let (respData, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(T.self, from: respData)
    }

    // MARK: Long poll

    func longPollServer() async throws -> LongPollServer {
        try await call("messages.getLongPollServer", ["lp_version": "3", "need_pts": "0"])
    }
}

// MARK: - Wall

struct WallPost: Decodable, Identifiable, Codable {
    let id: Int
    let date: Int
    let text: String
    var likes: Count?
    var comments: Count?
    var reposts: Count?
    var views: Count?
    @Lossy var attachments: [Attachment]
    var copy_history: [WallPost]?

    struct Count: Codable { let count: Int }

    enum K: String, CodingKey {
        case id, date, text, likes, comments, reposts, views, attachments, copy_history
    }

    // Same lenience as messages: one odd post must not empty the wall.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        date = try c.decodeIfPresent(Int.self, forKey: .date) ?? 0
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        likes = try? c.decodeIfPresent(Count.self, forKey: .likes)
        comments = try? c.decodeIfPresent(Count.self, forKey: .comments)
        reposts = try? c.decodeIfPresent(Count.self, forKey: .reposts)
        views = try? c.decodeIfPresent(Count.self, forKey: .views)
        _attachments = try c.decode(Lossy<Attachment>.self, forKey: .attachments)
        copy_history = try c.decodeIfPresent(Lossy<WallPost>.self, forKey: .copy_history)?.wrappedValue
    }

    /// Reposts carry their body in copy_history — show that when the post itself is empty.
    var displayText: String { text.isEmpty ? (copy_history?.first?.text ?? "") : text }
    var photos: [URL] {
        let own = attachments + (copy_history?.first?.attachments ?? [])
        return own.compactMap { a in
            a.photo?.sizes.max(by: { $0.width < $1.width }).flatMap { URL(string: $0.url) }
        }
    }
}

private struct WallResponse: Decodable {
    let count: Int?
    @Lossy var items: [WallPost]
}

extension VK {
    func wall(ownerId: Int, count: Int = 30) async throws -> [WallPost] {
        let r: WallResponse = try await call("wall.get",
            ["owner_id": String(ownerId), "count": String(count), "extended": "0"])
        return r.items
    }

    func photos(ownerId: Int, count: Int = 60) async throws -> [URL] {
        // photos.getAll items carry `sizes` directly, not a wall attachment.
        struct Item: Decodable { @Lossy var sizes: [AttachmentImage] }
        struct Resp: Decodable { @Lossy var items: [Item] }
        let r: Resp = try await call("photos.getAll",
            ["owner_id": String(ownerId), "count": String(count), "photo_sizes": "1"])
        return r.items.compactMap { item in
            item.sizes.max(by: { $0.width < $1.width }).flatMap { URL(string: $0.url) }
        }
    }
}
