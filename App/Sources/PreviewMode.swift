import Foundation

// Launch-argument driven UI preview: lets CI boot the app in a simulator with
// believable data and screenshot the real screens, so layout and translucency
// can be checked by looking instead of by guessing.
// ponytail: fake data seeded through the normal cache, no parallel UI.
enum PreviewMode {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-uiPreview") }
    /// Open straight into a conversation rather than the chat list.
    static var opensChat: Bool { ProcessInfo.processInfo.arguments.contains("-uiPreviewChat") }
    /// Open the chat list directly (the first tab is Contacts).
    static var opensList: Bool { ProcessInfo.processInfo.arguments.contains("-uiPreviewList") }

    static let ownId = 1
    static let peerId = 42

    static let account = Account(id: ownId, name: "Тест Тестов", token: "preview", photo: nil)

    /// Seed the on-disk caches the real screens already read from.
    static func seed() {
        guard isOn else { return }
        let now = Int(Date().timeIntervalSince1970)

        let rows = (0..<12).map { i in
            ChatRow(peerId: i == 0 ? peerId : 1000 + i,
                    title: names[i % names.count],
                    subtitle: previews[i % previews.count],
                    date: now - i * 3600,
                    avatar: nil,
                    online: i % 3 == 0)
        }
        DiskCache.save(rows, as: "chats-\(ownId)")

        var msgs: [ChatMessage] = []
        for (i, text) in sample.enumerated() {
            let mine = i % 3 == 2
            msgs.append(ChatMessage(
                msg: Msg(id: 100 + i,
                         from_id: mine ? ownId : peerId,
                         text: text,
                         date: now - (sample.count - i) * 300,
                         conversation_message_id: 100 + i),
                senderName: mine ? "Тест Тестов" : "Салават",
                senderAvatar: nil,
                replyAuthor: nil))
        }
        DiskCache.save(msgs, as: "chat-\(peerId)")
    }

    private static let names = ["Салават", "Рита", "Эмиль", "Мама", "Работа", "Друзья"]
    private static let previews = ["Привет! Как дела?", "Ну ты видел вообще",
                                   "Ок, договорились", "🖼 Фото", "🎤 Голосовое"]
    private static let sample = [
        "Привет, ты уже посмотрел?",
        "Да, вчера вечером. Довольно неплохо получилось, мне понравилось как всё выглядит в итоге.",
        "Ага, я тоже так подумал",
        "Слушай, а во сколько завтра встречаемся?",
        "Давай часа в три, мне удобно",
        "Хорошо, тогда до завтра 👋",
    ]
}

extension Msg {
    /// Memberwise-style init for preview data (the real one decodes from JSON).
    init(id: Int, from_id: Int, text: String, date: Int, conversation_message_id: Int?) {
        self.id = id
        self.from_id = from_id
        self.text = text
        self.date = date
        self.conversation_message_id = conversation_message_id
        self.attachments = nil
        self.reply_message = nil
        self.fwd_messages = nil
        self.reactions = nil
    }
}
