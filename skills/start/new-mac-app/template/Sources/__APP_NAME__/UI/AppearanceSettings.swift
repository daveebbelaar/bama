import SwiftUI

/// Settings > Appearance: the accent color. Light and dark mode follow the Mac.
struct AppearanceSettings: View {
    @Bindable private var store = ThemeStore.shared

    var body: some View {
        Section {
            AccentPreview()
                .padding(.vertical, Space.xs)
            LabeledContent("Accent color") {
                VStack(alignment: .trailing, spacing: Space.xs) {
                    HStack(spacing: Space.sm) {
                        ForEach(Theme.all) { theme in
                            AccentSwatch(theme: theme, selected: store.themeID == theme.id) {
                                store.themeID = theme.id
                            }
                        }
                    }
                    Text(store.theme.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// A small sample window in the chosen accent: a sidebar, two tasks, a tag,
/// a button, and a switch. It redraws as people pick a color.
/// Swap the sample words for ones from this app.
private struct AccentPreview: View {
    private let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(height: 152)
        .background(.background, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.separator, lineWidth: 1))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of the accent color")
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.xs) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(.quaternary).frame(width: 8, height: 8)
                }
            }
            .padding(.leading, Space.xs)
            .padding(.bottom, Space.sm)
            sidebarRow("Inbox", symbol: "tray", selected: true)
            sidebarRow("Today", symbol: "star", selected: false)
            sidebarRow("Done", symbol: "checkmark.circle", selected: false)
            Spacer(minLength: 0)
        }
        .padding(Space.sm)
        .frame(width: 128)
        .background(.background.secondary)
    }

    private func sidebarRow(_ title: String, symbol: String, selected: Bool) -> some View {
        Label(title, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(selected ? Palette.onAccent : .primary)
            .padding(.horizontal, Space.sm)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            .background(selected ? Palette.accent : .clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Inbox").font(.headline)
                Spacer()
                Text("1 left").font(.caption).foregroundStyle(Palette.accentText)
            }
            task("Pick a color", done: true)
            task("Ship the first build", done: false, tag: "Today")
            Spacer(minLength: 0)
            // Drawn, not real controls: the preview is a picture, and real
            // controls turn gray when the window is not in front.
            HStack {
                Label("Add Task", systemImage: "plus")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, Space.md)
                    .frame(height: 24)
                    .background(Palette.accent, in: Capsule())
                Spacer()
                Text("Focus").font(.caption).foregroundStyle(.secondary)
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: 28, height: 16)
                    .overlay(alignment: .trailing) {
                        Circle().fill(.white).padding(2).shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                    }
            }
        }
        .padding(Space.md)
    }

    private func task(_ title: String, done: Bool, tag: String? = nil) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            Text(title)
                .strikethrough(done)
                .foregroundStyle(done ? .secondary : .primary)
            Spacer()
            if let tag {
                Text(tag)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.accentText)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 2)
                    .background(Palette.accent.opacity(0.15), in: Capsule())
            }
        }
        .font(.callout)
    }
}

/// One color dot, like the accent row in System Settings.
private struct AccentSwatch: View {
    let theme: Theme
    let selected: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            Circle()
                .fill(fill)
                .frame(width: 16, height: 16)
                .overlay {
                    if selected {
                        Circle().fill(theme.onAccent).frame(width: 6, height: 6) // grid: ok
                    }
                }
                .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(theme.name)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var fill: AnyShapeStyle {
        if let tint = theme.tint {
            AnyShapeStyle(tint)
        } else {
            AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red],
                                          center: .center))
        }
    }
}
