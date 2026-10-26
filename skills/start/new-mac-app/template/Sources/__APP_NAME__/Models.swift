import Foundation
import SwiftData
import __APP_NAME__Kit

@Model
final class Item {
    var title: String
    var notes: String = ""
    var isStarred: Bool = false
    var createdAt: Date = Date.now
    /// A stable id for links, sync, and the agent CLI.
    var uuid: UUID = UUID()

    init(title: String) {
        self.title = title
    }
}

/// The sidebar pages. Snapshot mode walks through every case.
enum SidebarItem: String, CaseIterable, Identifiable {
    case all, starred

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Items"
        case .starred: "Starred"
        }
    }

    var symbol: String {
        switch self {
        case .all: "tray"
        case .starred: "star"
        }
    }
}

/// App-wide state that menus, toolbars, and views share.
@Observable
final class AppModel {
    let container: ModelContainer
    var sidebar: SidebarItem? = .all
    var selection: PersistentIdentifier?
    /// Settings reopens on the last tab. Test and snapshot runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: UserDefaults.standard.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { if !Store.isOverridden { UserDefaults.standard.set(settingsTab.rawValue, forKey: "settings.tab") } }
    }

    init(container: ModelContainer) {
        self.container = container
    }

    func addItem(title: String = "") {
        let item = Item(title: ItemTitle.clean(title))
        if sidebar == .starred { item.isStarred = true }
        container.mainContext.insert(item)
        selection = item.id
    }
}
