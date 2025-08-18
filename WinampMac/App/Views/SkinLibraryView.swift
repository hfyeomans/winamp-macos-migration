import SwiftUI
import UniformTypeIdentifiers
import AppKit
import CloudKit

/// Skin Library View - Comprehensive skin management with search, preview, and iCloud sync
/// Displays available skins in a grid layout with drag-and-drop import functionality
struct SkinLibraryView: View {
    @EnvironmentObject private var skinLibrary: SkinLibraryManager
    @EnvironmentObject private var appManager: AppManager
    
    @State private var searchText = ""
    @State private var selectedSkin: SkinLibraryItem?
    @State private var showingImportDialog = false
    @State private var showingDeleteAlert = false
    @State private var skinToDelete: SkinLibraryItem?
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    @State private var sortOrder: SkinSortOrder = .nameAscending
    @State private var gridItemSize: GridItemSize = .medium
    @State private var showingCloudSyncSettings = false
    @State private var hoveredSkin: SkinLibraryItem?
    
    // Filter states
    @State private var showingFilters = false
    @State private var selectedCategory: SkinCategory = .all
    @State private var selectedColorScheme: ColorScheme? = nil
    @State private var dateFilter: DateFilter = .all
    
    private let gridColumns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)
    ]
    
    private var filteredSkins: [SkinLibraryItem] {
        var skins = skinLibrary.skins
        
        // Apply search filter
        if !searchText.isEmpty {
            skins = skins.filter { skin in
                skin.name.localizedCaseInsensitiveContains(searchText) ||
                skin.author.localizedCaseInsensitiveContains(searchText) ||
                skin.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply category filter
        if selectedCategory != .all {
            skins = skins.filter { $0.category == selectedCategory }
        }
        
        // Apply color scheme filter
        if let colorScheme = selectedColorScheme {
            skins = skins.filter { $0.dominantColorScheme == colorScheme }
        }
        
        // Apply date filter
        switch dateFilter {
        case .lastWeek:
            let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            skins = skins.filter { $0.dateAdded >= weekAgo }
        case .lastMonth:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            skins = skins.filter { $0.dateAdded >= monthAgo }
        case .all:
            break
        }
        
        // Apply sort order
        switch sortOrder {
        case .nameAscending:
            skins.sort { $0.name < $1.name }
        case .nameDescending:
            skins.sort { $0.name > $1.name }
        case .dateAdded:
            skins.sort { $0.dateAdded > $1.dateAdded }
        case .author:
            skins.sort { $0.author < $1.author }
        case .popularity:
            skins.sort { $0.usageCount > $1.usageCount }
        }
        
        return skins
    }
    
    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            mainContentView
        }
        .navigationTitle("Skin Library")
        .toolbar {
            toolbarContent
        }
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [UTType(filenameExtension: "wsz")!],
            allowsMultipleSelection: true
        ) { result in
            handleSkinImport(result)
        }
        .alert("Delete Skin", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let skin = skinToDelete {
                    deleteSkin(skin)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(skinToDelete?.name ?? "")'? This action cannot be undone.")
        }
        .sheet(isPresented: $showingCloudSyncSettings) {
            CloudSyncSettingsView()
                .environmentObject(skinLibrary)
        }
        .onAppear {
            skinLibrary.loadSkins()
        }
        .onDrop(of: [.fileURL], isTargeted: .constant(false)) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - Sidebar View
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search skins...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Categories
            VStack(alignment: .leading, spacing: 8) {
                Label("Categories", systemImage: "folder")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                ForEach(SkinCategory.allCases, id: \.self) { category in
                    categoryRow(category)
                }
            }
            
            Divider()
            
            // Color Schemes
            VStack(alignment: .leading, spacing: 8) {
                Label("Color Schemes", systemImage: "paintpalette")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                colorSchemeFilters
            }
            
            Divider()
            
            // Date Filters
            VStack(alignment: .leading, spacing: 8) {
                Label("Date Added", systemImage: "calendar")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                ForEach(DateFilter.allCases, id: \.self) { filter in
                    dateFilterRow(filter)
                }
            }
            
            Spacer()
            
            // Cloud Sync Status
            cloudSyncStatusView
        }
        .padding()
        .frame(minWidth: 200, maxWidth: 250)
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        Group {
            if filteredSkins.isEmpty {
                emptyStateView
            } else {
                skinGridView
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isImporting {
                importProgressView
            }
        }
    }
    
    private var skinGridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(filteredSkins) { skin in
                    SkinGridItem(
                        skin: skin,
                        isSelected: selectedSkin?.id == skin.id,
                        isHovered: hoveredSkin?.id == skin.id,
                        size: gridItemSize
                    )
                    .onTapGesture {
                        selectedSkin = skin
                    }
                    .onHover { isHovered in
                        hoveredSkin = isHovered ? skin : nil
                    }
                    .contextMenu {
                        skinContextMenu(for: skin)
                    }
                    .onDoubleClick {
                        applySkin(skin)
                    }
                }
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Skins Found")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Import .wsz files to get started or adjust your search filters")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Import Skins...") {
                showingImportDialog = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack {
                // Grid size control
                Picker("Grid Size", selection: $gridItemSize) {
                    Image(systemName: "square.grid.3x3")
                        .tag(GridItemSize.small)
                    Image(systemName: "square.grid.2x2")
                        .tag(GridItemSize.medium)
                    Image(systemName: "square")
                        .tag(GridItemSize.large)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                
                // Sort control
                Picker("Sort", selection: $sortOrder) {
                    Text("Name ↑").tag(SkinSortOrder.nameAscending)
                    Text("Name ↓").tag(SkinSortOrder.nameDescending)
                    Text("Date Added").tag(SkinSortOrder.dateAdded)
                    Text("Author").tag(SkinSortOrder.author)
                    Text("Popular").tag(SkinSortOrder.popularity)
                }
                .frame(width: 120)
                
                Button("Import...") {
                    showingImportDialog = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        
        ToolbarItem(placement: .navigation) {
            HStack {
                Button(action: { showingFilters.toggle() }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .help("Show/Hide Filters")
                
                Button(action: { showingCloudSyncSettings = true }) {
                    Image(systemName: skinLibrary.isCloudSyncEnabled ? "cloud.fill" : "cloud")
                }
                .help("Cloud Sync Settings")
            }
        }
    }
    
    // MARK: - Sidebar Components
    
    @ViewBuilder
    private func categoryRow(_ category: SkinCategory) -> some View {
        Button(action: { selectedCategory = category }) {
            HStack {
                Image(systemName: category.iconName)
                    .frame(width: 16)
                
                Text(category.displayName)
                    .font(.body)
                
                Spacer()
                
                Text("\(skinLibrary.skinCount(for: category))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            .foregroundColor(selectedCategory == category ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedCategory == category ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var colorSchemeFilters: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { selectedColorScheme = nil }) {
                HStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 16, height: 16)
                    
                    Text("All Colors")
                        .font(.body)
                    
                    Spacer()
                }
                .foregroundColor(selectedColorScheme == nil ? .white : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedColorScheme == nil ? Color.accentColor : Color.clear)
                )
            }
            .buttonStyle(.plain)
            
            ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                colorSchemeRow(scheme)
            }
        }
    }
    
    @ViewBuilder
    private func colorSchemeRow(_ scheme: ColorScheme) -> some View {
        Button(action: { selectedColorScheme = scheme }) {
            HStack {
                Circle()
                    .fill(scheme == .light ? Color.white : Color.black)
                    .overlay(
                        Circle()
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .frame(width: 16, height: 16)
                
                Text(scheme == .light ? "Light" : "Dark")
                    .font(.body)
                
                Spacer()
            }
            .foregroundColor(selectedColorScheme == scheme ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedColorScheme == scheme ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func dateFilterRow(_ filter: DateFilter) -> some View {
        Button(action: { dateFilter = filter }) {
            HStack {
                Image(systemName: filter.iconName)
                    .frame(width: 16)
                
                Text(filter.displayName)
                    .font(.body)
                
                Spacer()
            }
            .foregroundColor(dateFilter == filter ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(dateFilter == filter ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var cloudSyncStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: skinLibrary.isCloudSyncEnabled ? "cloud.fill" : "cloud")
                    .foregroundColor(skinLibrary.isCloudSyncEnabled ? .green : .secondary)
                
                Text("iCloud Sync")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                if skinLibrary.isSyncing {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            
            Text(skinLibrary.cloudSyncStatus)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if !skinLibrary.isCloudSyncEnabled {
                Button("Enable") {
                    showingCloudSyncSettings = true
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func skinContextMenu(for skin: SkinLibraryItem) -> some View {
        Group {
            Button("Apply Skin") {
                applySkin(skin)
            }
            
            Button("Preview") {
                previewSkin(skin)
            }
            
            Divider()
            
            Button("Show in Finder") {
                showInFinder(skin)
            }
            
            Button("Get Info") {
                showSkinInfo(skin)
            }
            
            Divider()
            
            Button("Export...") {
                exportSkin(skin)
            }
            
            Button("Duplicate") {
                duplicateSkin(skin)
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                skinToDelete = skin
                showingDeleteAlert = true
            }
        }
    }
    
    private var importProgressView: some View {
        VStack(spacing: 12) {
            HStack {
                ProgressView()
                    .controlSize(.small)
                
                Text("Importing skins...")
                    .font(.caption)
            }
            
            ProgressView(value: importProgress, total: 1.0)
                .frame(width: 200)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .padding()
    }
    
    // MARK: - Actions
    
    private func handleSkinImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await importSkins(from: urls)
            }
        case .failure(let error):
            print("Failed to import skins: \(error)")
        }
    }
    
    private func importSkins(from urls: [URL]) async {
        await MainActor.run {
            isImporting = true
            importProgress = 0.0
        }
        
        let totalUrls = urls.count
        
        for (index, url) in urls.enumerated() {
            do {
                try await skinLibrary.importSkin(from: url)
                
                await MainActor.run {
                    importProgress = Double(index + 1) / Double(totalUrls)
                }
            } catch {
                print("Failed to import skin from \(url): \(error)")
            }
        }
        
        await MainActor.run {
            isImporting = false
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let urls = providers.compactMap { provider -> URL? in
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                // Handle synchronously for drag and drop
                var url: URL?
                let semaphore = DispatchSemaphore(value: 0)
                
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    }
                    semaphore.signal()
                }
                
                semaphore.wait()
                return url?.pathExtension.lowercased() == "wsz" ? url : nil
            }
            return nil
        }
        
        if !urls.isEmpty {
            Task {
                await importSkins(from: urls)
            }
            return true
        }
        
        return false
    }
    
    private func applySkin(_ skin: SkinLibraryItem) {
        Task {
            await appManager.loadSkin(from: skin.fileURL)
            skinLibrary.recordUsage(for: skin)
        }
    }
    
    private func previewSkin(_ skin: SkinLibraryItem) {
        // Open preview window
        let previewWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        previewWindow.title = "Preview: \(skin.name)"
        previewWindow.contentView = NSHostingView(
            rootView: SkinPreviewView(skin: skin)
        )
        previewWindow.center()
        previewWindow.makeKeyAndOrderFront(nil)
    }
    
    private func showInFinder(_ skin: SkinLibraryItem) {
        NSWorkspace.shared.activateFileViewerSelecting([skin.fileURL])
    }
    
    private func showSkinInfo(_ skin: SkinLibraryItem) {
        // Open skin info window
        let infoWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        infoWindow.title = "Skin Info: \(skin.name)"
        infoWindow.contentView = NSHostingView(
            rootView: SkinInfoView(skin: skin)
        )
        infoWindow.center()
        infoWindow.makeKeyAndOrderFront(nil)
    }
    
    private func exportSkin(_ skin: SkinLibraryItem) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "wsz")!]
        savePanel.nameFieldStringValue = "\(skin.name).wsz"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try FileManager.default.copyItem(at: skin.fileURL, to: url)
                } catch {
                    print("Failed to export skin: \(error)")
                }
            }
        }
    }
    
    private func duplicateSkin(_ skin: SkinLibraryItem) {
        Task {
            await skinLibrary.duplicateSkin(skin)
        }
    }
    
    private func deleteSkin(_ skin: SkinLibraryItem) {
        Task {
            await skinLibrary.deleteSkin(skin)
        }
    }
}

// MARK: - Supporting Views

extension View {
    func onDoubleClick(perform action: @escaping () -> Void) -> some View {
        self.onTapGesture(count: 2, perform: action)
    }
}

// MARK: - Enums and Types

enum SkinSortOrder: CaseIterable {
    case nameAscending
    case nameDescending
    case dateAdded
    case author
    case popularity
    
    var displayName: String {
        switch self {
        case .nameAscending: return "Name (A-Z)"
        case .nameDescending: return "Name (Z-A)"
        case .dateAdded: return "Date Added"
        case .author: return "Author"
        case .popularity: return "Most Used"
        }
    }
}

enum GridItemSize: CaseIterable {
    case small
    case medium
    case large
    
    var thumbnailSize: CGSize {
        switch self {
        case .small: return CGSize(width: 150, height: 100)
        case .medium: return CGSize(width: 200, height: 130)
        case .large: return CGSize(width: 250, height: 160)
        }
    }
}

enum SkinCategory: CaseIterable {
    case all
    case classic
    case modern
    case gaming
    case abstract
    case minimal
    case colorful
    case dark
    case light
    case custom
    
    var displayName: String {
        switch self {
        case .all: return "All Skins"
        case .classic: return "Classic"
        case .modern: return "Modern"
        case .gaming: return "Gaming"
        case .abstract: return "Abstract"
        case .minimal: return "Minimal"
        case .colorful: return "Colorful"
        case .dark: return "Dark"
        case .light: return "Light"
        case .custom: return "Custom"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "square.grid.3x3"
        case .classic: return "clock"
        case .modern: return "sparkles"
        case .gaming: return "gamecontroller"
        case .abstract: return "paintbrush"
        case .minimal: return "circle"
        case .colorful: return "paintpalette"
        case .dark: return "moon"
        case .light: return "sun.max"
        case .custom: return "wrench.and.screwdriver"
        }
    }
}

enum DateFilter: CaseIterable {
    case all
    case lastWeek
    case lastMonth
    
    var displayName: String {
        switch self {
        case .all: return "All Time"
        case .lastWeek: return "Last Week"
        case .lastMonth: return "Last Month"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "calendar"
        case .lastWeek: return "calendar.badge.clock"
        case .lastMonth: return "calendar.badge.minus"
        }
    }
}