import SwiftUI

// Pick a destination for forwarded messages. Reads the cached chat list so it
// opens instantly and works offline-ish, same as every other screen here.
struct ForwardPicker: View {
    let ownId: Int
    let onPick: (ChatRow) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [ChatRow] = []
    @State private var query = ""

    private var shown: [ChatRow] {
        query.isEmpty ? rows
            : rows.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(shown) { row in
                Button {
                    onPick(row)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        AvatarView(url: row.avatar, name: row.title, id: row.peerId, size: 40)
                        Text(row.title).foregroundStyle(TG.title)
                        Spacer()
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "Куда переслать")
            .navigationTitle("Переслать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
            .task { rows = DiskCache.load([ChatRow].self, "chats-\(ownId)") ?? [] }
        }
    }
}
