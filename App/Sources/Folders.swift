import SwiftUI

// Chat folders are ours alone — VK has no matching API, so they live on the
// device and only filter the list we already have.
struct ChatFolder: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String            // emoji goes in the name, as in the reference
    var peerIds: [Int]
}

enum FolderStore {
    private static let key = "chat_folders"

    static func load() -> [ChatFolder] {
        guard let d = UserDefaults.standard.data(forKey: key),
              let f = try? JSONDecoder().decode([ChatFolder].self, from: d) else { return [] }
        return f
    }

    static func save(_ folders: [ChatFolder]) {
        guard let d = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(d, forKey: key)
    }
}

/// Horizontal strip of folder tabs: "Все" first, then the user's, then "+".
struct FolderStrip: View {
    let folders: [ChatFolder]
    @Binding var selected: UUID?
    let onAdd: () -> Void
    let onEdit: (ChatFolder) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: "Все", active: selected == nil) { selected = nil }
                ForEach(folders) { f in
                    chip(title: f.name, active: selected == f.id) { selected = f.id }
                        .contextMenu {
                            Button { onEdit(f) } label: { Label("Изменить", systemImage: "pencil") }
                        }
                }
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 12)
        }
        .scrollClipDisabled()
    }

    // No filled capsule behind the active folder — the selection reads from the
    // accent colour and weight alone.
    private func chip(title: String, active: Bool, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(title)
                .font(.subheadline.weight(active ? .semibold : .regular))
                .foregroundStyle(active ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

/// Name the folder and tick the chats that belong to it.
struct FolderEditor: View {
    @Environment(\.dismiss) private var dismiss
    let rows: [ChatRow]
    @State var folder: ChatFolder
    let onSave: (ChatFolder) -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        NavigationStack {
            List {
                Section("Название папки") {
                    TextField("Например, Семья 🌸", text: $folder.name)
                }
                Section("Чаты в папке") {
                    ForEach(rows) { row in
                        Button {
                            if let i = folder.peerIds.firstIndex(of: row.peerId) {
                                folder.peerIds.remove(at: i)
                            } else {
                                folder.peerIds.append(row.peerId)
                            }
                        } label: {
                            HStack {
                                Text(row.title).foregroundStyle(.primary)
                                Spacer()
                                if folder.peerIds.contains(row.peerId) {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
                if let onDelete {
                    Section {
                        Button("Удалить папку", role: .destructive) { onDelete(); dismiss() }
                    }
                }
            }
            .navigationTitle("Папка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { onSave(folder); dismiss() }
                        .disabled(folder.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
