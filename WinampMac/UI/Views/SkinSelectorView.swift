//
//  SkinSelectorView.swift
//  WinampMac
//
//  Modern skin selector with grid layout and quick preview
//  Designed for browsing and managing converted skins
//

import SwiftUI

@available(macOS 15.0, *)
public struct SkinSelectorView: View {
    @StateObject private var skinManager = SkinSelectorManager()
    @State private var selectedSkin: SkinInfo?
    @State private var showingImporter = false
    @State private var searchText = ""
    @State private var sortOption: SortOption = .name
    @State private var viewMode: ViewMode = .grid
    @State private var hoveredSkin: SkinInfo?
    
    private let gridColumns = [
        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)
    ]
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and controls bar
                controlBar
                
                // Main content area
                ZStack {
                    if skinManager.skins.isEmpty {
                        EmptyStateView {
                            showingImporter = true
                        }
                    } else {
                        contentView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Winamp Skins")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import Skins", systemImage: "plus.circle")
                    }
                    
                    Picker("View Mode", selection: $viewMode) {
                        Label("Grid", systemImage: "square.grid.2x2").tag(ViewMode.grid)
                        Label("List", systemImage: "list.bullet").tag(ViewMode.list)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .onAppear {
            skinManager.loadSkins()
        }
        .sheet(isPresented: $showingImporter) {
            SkinImportView()
        }
        .sheet(item: $selectedSkin) { skin in
            SkinDetailView(skin: skin) { appliedSkin in
                skinManager.setActiveSkin(appliedSkin)
            }
        }
    }
    
    private var controlBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search skins...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                
                // Sort picker
                Picker("Sort", selection: $sortOption) {
                    Text("Name").tag(SortOption.name)
                    Text("Author").tag(SortOption.author)
                    Text("Recently Used").tag(SortOption.recent)
                    Text("Date Added").tag(SortOption.dateAdded)
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
            
            // Active skin indicator
            if let activeSkin = skinManager.activeSkin {
                ActiveSkinIndicator(skin: activeSkin)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch viewMode {
        case .grid:
            gridView
        case .list:
            listView
        }
    }
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(filteredSkins) { skin in
                    SkinGridCard(
                        skin: skin,
                        isActive: skin.id == skinManager.activeSkin?.id,
                        isHovered: skin.id == hoveredSkin?.id
                    ) {
                        selectedSkin = skin
                    }
                    .onHover { hovering in
                        hoveredSkin = hovering ? skin : nil
                    }
                    .contextMenu {
                        SkinContextMenu(skin: skin, manager: skinManager)
                    }
                }
            }
            .padding(20)
        }
    }
    
    private var listView: some View {
        List(filteredSkins) { skin in
            SkinListRow(
                skin: skin,
                isActive: skin.id == skinManager.activeSkin?.id
            ) {
                selectedSkin = skin
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .contextMenu {
                SkinContextMenu(skin: skin, manager: skinManager)
            }
        }
        .listStyle(.plain)
    }
    
    private var filteredSkins: [SkinInfo] {
        let filtered = searchText.isEmpty ? 
            skinManager.skins : 
            skinManager.skins.filter { skin in
                skin.name.localizedCaseInsensitiveContains(searchText) ||
                skin.author.localizedCaseInsensitiveContains(searchText)
            }
        
        return filtered.sorted { lhs, rhs in
            switch sortOption {
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .author:
                return lhs.author.localizedCaseInsensitiveCompare(rhs.author) == .orderedAscending
            case .recent:
                return (lhs.lastUsed ?? .distantPast) > (rhs.lastUsed ?? .distantPast)
            case .dateAdded:
                return lhs.dateAdded > rhs.dateAdded
            }
        }
    }
}

// MARK: - Grid Card Component
struct SkinGridCard: View {
    let skin: SkinInfo
    let isActive: Bool
    let isHovered: Bool
    let onTap: () -> Void
    
    @State private var imageLoaded = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Preview image with overlay
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.gradient)
                        .aspectRatio(2.7, contentMode: .fit) // Winamp's classic ratio
                    
                    if let previewImage = skin.previewImage {
                        Image(nsImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .opacity(imageLoaded ? 1 : 0)
                            .onAppear {
                                withAnimation(.easeIn(duration: 0.3)) {
                                    imageLoaded = true
                                }
                            }
                    } else {
                        // Placeholder with skin name
                        VStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Text(skin.name)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .padding()
                    }
                    
                    // Active indicator
                    if isActive {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                                    .background(.black.opacity(0.5), in: Circle())
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                    
                    // Hover overlay
                    if isHovered {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.3))
                            .overlay {
                                Image(systemName: "eye.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                    }
                }
                
                // Skin info
                VStack(spacing: 4) {
                    Text(skin.name)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text("by \(skin.author)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .shadow(color: .black.opacity(isHovered ? 0.2 : 0.1), radius: isHovered ? 8 : 4)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.regularMaterial)
            .stroke(isActive ? .blue : .clear, lineWidth: 2)
    }
}

// MARK: - List Row Component
struct SkinListRow: View {
    let skin: SkinInfo
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Mini preview
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.gradient)
                        .frame(width: 80, height: 30)
                    
                    if let previewImage = skin.previewImage {
                        Image(nsImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 76, height: 26)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                
                // Skin details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(skin.name)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        
                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("by \(skin.author)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if let lastUsed = skin.lastUsed {
                            Text("Used \(lastUsed, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                Spacer()
                
                // Quick actions
                HStack(spacing: 8) {
                    Button {
                        // Quick apply
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    
                    Button {
                        // More options
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .background(isActive ? .blue.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Active Skin Indicator
struct ActiveSkinIndicator: View {
    let skin: SkinInfo
    
    var body: some View {
        HStack(spacing: 12) {
            // Mini preview
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.black.gradient)
                    .frame(width: 60, height: 22)
                
                if let previewImage = skin.previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Active: \(skin.name)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text("by \(skin.author)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let onImport: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Skins Imported Yet")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text("Import your first Winamp skin to get started")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Import Winamp Skins") {
                onImport()
            }
            .buttonStyle(WinampButtonStyle())
            
            // Sample skins suggestion
            VStack(spacing: 12) {
                Text("Don't have any skins?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Button("Download Classic Pack") {
                    // Download classic skins
                }
                .buttonStyle(WinampSecondaryButtonStyle())
            }
        }
        .frame(maxWidth: 400)
    }
}

// MARK: - Context Menu
struct SkinContextMenu: View {
    let skin: SkinInfo
    let manager: SkinSelectorManager
    
    var body: some View {
        Group {
            Button("Apply Skin") {
                manager.setActiveSkin(skin)
            }
            
            Button("Show Details") {
                // Show skin details
            }
            
            Divider()
            
            Button("Reveal in Finder") {
                manager.revealInFinder(skin)
            }
            
            Button("Export...") {
                manager.exportSkin(skin)
            }
            
            Divider()
            
            Button("Delete Skin", role: .destructive) {
                manager.deleteSkin(skin)
            }
        }
    }
}

// MARK: - Supporting Types
enum ViewMode: String, CaseIterable {
    case grid = "grid"
    case list = "list"
}

enum SortOption: String, CaseIterable {
    case name = "name"
    case author = "author"
    case recent = "recent"
    case dateAdded = "dateAdded"
}

struct SkinInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let author: String
    let previewImage: NSImage?
    let dateAdded: Date
    let lastUsed: Date?
    let filePath: URL
    let isActive: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SkinInfo, rhs: SkinInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Skin Manager
@MainActor
class SkinSelectorManager: ObservableObject {
    @Published var skins: [SkinInfo] = []
    @Published var activeSkin: SkinInfo?
    @Published var isLoading = false
    
    func loadSkins() {
        // Mock data for demonstration
        skins = [
            SkinInfo(
                name: "Carrie-Anne Moss",
                author: "Matrix Fan",
                previewImage: nil,
                dateAdded: Date().addingTimeInterval(-86400),
                lastUsed: Date().addingTimeInterval(-3600),
                filePath: URL(fileURLWithPath: "/path/to/skin1"),
                isActive: true
            ),
            SkinInfo(
                name: "Deus Ex Amp",
                author: "AJ",
                previewImage: nil,
                dateAdded: Date().addingTimeInterval(-172800),
                lastUsed: nil,
                filePath: URL(fileURLWithPath: "/path/to/skin2"),
                isActive: false
            ),
            SkinInfo(
                name: "Netscape Winamp",
                author: "Retro Designer",
                previewImage: nil,
                dateAdded: Date().addingTimeInterval(-259200),
                lastUsed: Date().addingTimeInterval(-86400),
                filePath: URL(fileURLWithPath: "/path/to/skin3"),
                isActive: false
            ),
            SkinInfo(
                name: "Purple Glow",
                author: "Unknown",
                previewImage: nil,
                dateAdded: Date().addingTimeInterval(-345600),
                lastUsed: Date().addingTimeInterval(-172800),
                filePath: URL(fileURLWithPath: "/path/to/skin4"),
                isActive: false
            )
        ]
        
        activeSkin = skins.first { $0.isActive }
    }
    
    func setActiveSkin(_ skin: SkinInfo) {
        // Update active skin
        activeSkin = skin
        
        // Update skin list
        skins = skins.map { existingSkin in
            var updated = existingSkin
            updated = SkinInfo(
                name: updated.name,
                author: updated.author,
                previewImage: updated.previewImage,
                dateAdded: updated.dateAdded,
                lastUsed: skin.id == updated.id ? Date() : updated.lastUsed,
                filePath: updated.filePath,
                isActive: skin.id == updated.id
            )
            return updated
        }
    }
    
    func revealInFinder(_ skin: SkinInfo) {
        NSWorkspace.shared.selectFile(skin.filePath.path, inFileViewerRootedAtPath: "")
    }
    
    func exportSkin(_ skin: SkinInfo) {
        // Export skin functionality
    }
    
    func deleteSkin(_ skin: SkinInfo) {
        skins.removeAll { $0.id == skin.id }
        if activeSkin?.id == skin.id {
            activeSkin = nil
        }
    }
}