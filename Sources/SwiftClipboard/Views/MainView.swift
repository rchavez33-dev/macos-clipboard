import SwiftUI

struct MainView: View {
    @EnvironmentObject private var store: ClipboardStore
    @EnvironmentObject private var themes: ThemeManager
    @ObservedObject var state: PanelState

    var onPaste: (ClipItem) -> Void
    var onCopy: (ClipItem) -> Void
    var onClose: () -> Void

    var body: some View {
        let theme = themes.theme
        let items = state.filtered(store.items)

        VStack(spacing: 14) {
            ToolbarView(state: state, onClose: onClose)

            if items.isEmpty {
                EmptyPlaceholderView(isFiltering: !state.query.isEmpty || state.tab != .all)
            } else {
                ItemCollectionView(items: items, state: state,
                                   onPaste: onPaste, onCopy: onCopy)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                VisualEffectView(material: theme.panelMaterial)
                theme.panelTint
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.panelCornerRadius, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: themes.preset)
    }
}

// MARK: - Toolbar (SearchBar + TabBar)

private struct ToolbarView: View {
    @EnvironmentObject private var themes: ThemeManager
    @ObservedObject var state: PanelState
    var onClose: () -> Void

    var body: some View {
        let theme = themes.theme
        HStack(spacing: 12) {
            SearchBarView(state: state)
                .frame(width: 240)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(PanelState.Tab.allCases) { tab in
                        TabChip(tab: tab, isSelected: state.tab == tab) {
                            state.tab = tab
                            state.selectedIndex = 0
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Menu {
                Picker("Tema", selection: $themes.preset) {
                    ForEach(ThemePreset.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "paintpalette.fill")
                    .foregroundStyle(theme.tabText)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Cambiar tema")

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(theme.tabText.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Cerrar (Esc)")
        }
        .frame(height: 32)
    }
}

private struct SearchBarView: View {
    @EnvironmentObject private var themes: ThemeManager
    @ObservedObject var state: PanelState
    @FocusState private var focused: Bool

    var body: some View {
        let theme = themes.theme
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.searchText.opacity(0.5))
            TextField("Buscar…", text: $state.query)
                .textFieldStyle(.plain)
                .foregroundStyle(theme.searchText)
                .focused($focused)
            if !state.query.isEmpty {
                Button { state.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.searchText.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(theme.searchBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onChange(of: state.query) { _, _ in state.selectedIndex = 0 }
        .onChange(of: state.focusToken) { _, _ in focused = true }
        .onAppear { focused = true }
    }
}

private struct TabChip: View {
    @EnvironmentObject private var themes: ThemeManager
    let tab: PanelState.Tab
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let theme = themes.theme
        Button(action: action) {
            Label(tab.title, systemImage: tab.symbol)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .frame(height: 26)
                .foregroundStyle(isSelected ? theme.tabSelectedText : theme.tabText)
                .background(
                    Capsule().fill(isSelected ? theme.tabSelectedBackground
                                              : theme.tabText.opacity(hovering ? 0.12 : 0))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Collection

private struct ItemCollectionView: View {
    let items: [ClipItem]
    @ObservedObject var state: PanelState
    @EnvironmentObject private var store: ClipboardStore
    var onPaste: (ClipItem) -> Void
    var onCopy: (ClipItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ItemCard(item: item, index: index, isSelected: index == state.selectedIndex)
                            .id(item.id)
                            .onTapGesture(count: 2) { onPaste(item) }
                            .onTapGesture { state.selectedIndex = index }
                            .contextMenu {
                                Button("Pegar") { onPaste(item) }
                                Button("Copiar") { onCopy(item) }
                                Button(item.isPinned ? "Quitar de fijados" : "Fijar") {
                                    store.togglePin(item.id)
                                }
                                Divider()
                                Button("Eliminar", role: .destructive) { store.delete(item.id) }
                            }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
            .onChange(of: state.selectedIndex) { _, newValue in
                guard items.indices.contains(newValue) else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(items[newValue].id, anchor: .center)
                }
            }
        }
    }
}

private struct EmptyPlaceholderView: View {
    @EnvironmentObject private var themes: ThemeManager
    let isFiltering: Bool

    var body: some View {
        let theme = themes.theme
        VStack(spacing: 8) {
            Image(systemName: isFiltering ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 34, weight: .light))
            Text(isFiltering ? "Sin resultados" : "Nada por aquí todavía")
                .font(.system(size: 15, weight: .semibold))
            Text(isFiltering ? "Prueba con otra búsqueda o pestaña." : "Copia algo con ⌘C y aparecerá aquí.")
                .font(.system(size: 12))
        }
        .foregroundStyle(theme.secondaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Background

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = material
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
