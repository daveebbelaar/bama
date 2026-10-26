import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            ItemList(page: model.sidebar ?? .all)
                .navigationSplitViewColumnWidth(min: 260, ideal: 320)
        } detail: {
            ItemDetail()
        }
        .task {
            SeedData.insertIfRequested(into: model)
            SelfTest.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model, openSettings: openSettings)
        }
    }

    private var sidebar: some View {
        @Bindable var model = model
        return List(SidebarItem.allCases, selection: $model.sidebar) { page in
            Label(page.title, systemImage: page.symbol)
                .tag(page)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 212)
    }
}

struct ItemList: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    let page: SidebarItem

    private var visible: [Item] {
        page == .starred ? items.filter(\.isStarred) : items
    }

    var body: some View {
        @Bindable var model = model
        List(visible, selection: $model.selection) { item in
            Label(item.title, systemImage: item.isStarred ? "star.fill" : "circle")
                .tag(item.id)
                .contextMenu {
                    Button("Delete", role: .destructive) { context.delete(item) }
                }
        }
        .overlay {
            if visible.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: page.symbol,
                    description: Text("Press Command-N to add one.")
                )
            }
        }
        .navigationTitle(page.title)
        .toolbar {
            ToolbarItem {
                Button("New Item", systemImage: "plus") { model.addItem() }
                    .help("Add an item (Command-N)")
            }
        }
    }
}

struct ItemDetail: View {
    @Environment(AppModel.self) private var model
    @Query private var items: [Item]

    var body: some View {
        if let item = items.first(where: { $0.id == model.selection }) {
            @Bindable var item = item
            Form {
                TextField("Title", text: $item.title)
                Toggle("Starred", isOn: $item.isStarred)
                TextField("Notes", text: $item.notes, axis: .vertical)
                    .lineLimit(4...)
            }
            .formStyle(.grouped)
            } else {
            ContentUnavailableView("No Selection", systemImage: "sidebar.right")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
    }
}
