import SwiftUI

// TG-style long-press overlay: horizontal reaction pill + a glass action menu.
struct MessageActionsOverlay: View {
    let cm: ChatMessage
    let mine: Bool
    let isChat: Bool
    var statusText: String? = nil
    let hasReactions: Bool
    let onReact: (Int) -> Void
    let onRemoveReaction: () -> Void
    let onReply: () -> Void
    let onEdit: () -> Void
    let onForward: () -> Void
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onPin: () -> Void
    let onDeleteForMe: () -> Void
    let onDeleteForAll: () -> Void
    let onDismiss: () -> Void

    /// VK refuses messages.edit past 24h, so don't offer a button that only errors.
    private var canEdit: Bool {
        !cm.msg.text.isEmpty
            && Date().timeIntervalSince1970 - Double(cm.msg.date) < 24 * 3600
    }

    var body: some View {
        ZStack {
            // Blur the chat behind, the way iOS context menus do — a flat dim
            // just darkened the screen and read as a bug.
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            VStack(spacing: 12) {
                reactionPill
                MessageRow(cm: cm, mine: mine, isChat: isChat)
                    .allowsHitTesting(false)
                if let statusText {
                    Text(statusText).font(.caption2).foregroundStyle(.white.opacity(0.85))
                }
                menu
            }
            .padding(.horizontal, 20)
        }
    }

    private var reactionPill: some View {
        HStack(spacing: 10) {
            ForEach(reactionSet, id: \.id) { r in
                Button { onReact(r.id); onDismiss() } label: {
                    Text(r.emoji).font(.system(size: 30))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .glassEffect(in: Capsule())
    }

    private var menu: some View {
        VStack(spacing: 0) {
            row("Ответить", "arrowshape.turn.up.left", action: onReply)
            // VK only allows editing your own text, and only for 24 hours.
            if mine && canEdit {
                Divider()
                row("Редактировать", "pencil", action: onEdit)
            }
            Divider()
            row("Переслать", "arrowshape.turn.up.right", action: onForward)
            Divider()
            row("Выбрать", "checkmark.circle", action: onSelect)
            Divider()
            row("Копировать", "doc.on.doc", action: onCopy)
            Divider()
            row("Закрепить", "pin", action: onPin)
            if hasReactions {
                Divider()
                row("Убрать реакцию", "face.dashed", action: onRemoveReaction)
            }
            Divider()
            row("Удалить у себя", "trash", destructive: true, action: onDeleteForMe)
            if mine {
                Divider()
                row("Удалить у всех", "trash.fill", destructive: true, action: onDeleteForAll)
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: 260)
    }

    private func row(_ title: String, _ icon: String, destructive: Bool = false,
                     action: @escaping () -> Void) -> some View {
        Button { action(); onDismiss() } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: icon)
            }
            .foregroundStyle(destructive ? Color.red : Color.primary)
            .padding(.horizontal, 16).padding(.vertical, 13)
        }
    }
}
