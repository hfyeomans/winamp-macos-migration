//
//  SkinComparisonView.swift
//  WinampMac
//
//  Side-by-side comparison view for original vs converted skins
//  Features interactive testing and debug overlays
//

import SwiftUI

@available(macOS 15.0, *)
public struct SkinComparisonView: View {
    let skin: PreviewSkin
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: ComparisonMode = .sideBySide
    @State private var showingDebugOverlay = false
    @State private var showingHitTestRegions = false
    @State private var selectedComponent: SkinComponent?
    @State private var testingInteraction = false
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode selector
                Picker("Comparison Mode", selection: $selectedMode) {
                    Text("Side by Side").tag(ComparisonMode.sideBySide)
                    Text("Overlay").tag(ComparisonMode.overlay)
                    Text("Slider").tag(ComparisonMode.slider)
                    Text("Original Only").tag(ComparisonMode.original)
                    Text("Converted Only").tag(ComparisonMode.converted)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Main comparison area
                comparisonContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Controls and info
                bottomControls
            }
            .navigationTitle("Skin Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingHitTestRegions.toggle()
                    } label: {
                        Label("Hit Test Regions", systemImage: "scope")
                    }
                    .toggleStyle(.button)
                    
                    Button {
                        showingDebugOverlay.toggle()
                    } label: {
                        Label("Debug Info", systemImage: "info.circle")
                    }
                    .toggleStyle(.button)
                }
            }
        }
        .frame(width: 900, height: 700)
    }
    
    @ViewBuilder
    private var comparisonContent: some View {
        switch selectedMode {
        case .sideBySide:
            sideBySideView
        case .overlay:
            overlayView
        case .slider:
            sliderView
        case .original:
            singleView(isOriginal: true)
        case .converted:
            singleView(isOriginal: false)
        }
    }
    
    private var sideBySideView: some View {
        HStack(spacing: 20) {
            // Original skin
            VStack(spacing: 8) {
                Text("Original (Windows)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                SkinDisplayView(
                    image: skin.originalImage,
                    title: "Original",
                    showDebugOverlay: showingDebugOverlay,
                    showHitTestRegions: showingHitTestRegions,
                    isOriginal: true,
                    selectedComponent: $selectedComponent
                )
            }
            
            // Conversion arrow
            VStack {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("Converted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .opacity(0.7)
            
            // Converted skin
            VStack(spacing: 8) {
                Text("Converted (macOS)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                SkinDisplayView(
                    image: skin.previewImage,
                    title: "Converted",
                    showDebugOverlay: showingDebugOverlay,
                    showHitTestRegions: showingHitTestRegions,
                    isOriginal: false,
                    selectedComponent: $selectedComponent
                )
            }
        }
        .padding(20)
    }
    
    private var overlayView: some View {
        ZStack {
            // Base layer (converted)
            SkinDisplayView(
                image: skin.previewImage,
                title: "Converted (Base)",
                showDebugOverlay: showingDebugOverlay,
                showHitTestRegions: showingHitTestRegions,
                isOriginal: false,
                selectedComponent: $selectedComponent
            )
            
            // Overlay layer (original with transparency)
            SkinDisplayView(
                image: skin.originalImage,
                title: "Original (Overlay)",
                showDebugOverlay: false,
                showHitTestRegions: false,
                isOriginal: true,
                selectedComponent: .constant(nil)
            )
            .opacity(0.5)
            .blendMode(.difference)
        }
        .padding(20)
    }
    
    private var sliderView: some View {
        BeforeAfterSliderView(
            beforeImage: skin.originalImage,
            afterImage: skin.previewImage,
            beforeTitle: "Original",
            afterTitle: "Converted",
            showDebugOverlay: showingDebugOverlay,
            showHitTestRegions: showingHitTestRegions,
            selectedComponent: $selectedComponent
        )
        .padding(20)
    }
    
    private func singleView(isOriginal: Bool) -> some View {
        VStack(spacing: 16) {
            Text(isOriginal ? "Original (Windows)" : "Converted (macOS)")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            SkinDisplayView(
                image: isOriginal ? skin.originalImage : skin.previewImage,
                title: isOriginal ? "Original" : "Converted",
                showDebugOverlay: showingDebugOverlay,
                showHitTestRegions: showingHitTestRegions,
                isOriginal: isOriginal,
                selectedComponent: $selectedComponent
            )
        }
        .padding(20)
    }
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Component details
            if let component = selectedComponent {
                ComponentDetailView(component: component)
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Test Interactions") {
                    testingInteraction.toggle()
                }
                .buttonStyle(WinampSecondaryButtonStyle())
                
                Button("Performance Test") {
                    runPerformanceTest()
                }
                .buttonStyle(WinampSecondaryButtonStyle())
                
                Spacer()
                
                Button("Export Comparison") {
                    exportComparison()
                }
                .buttonStyle(WinampSecondaryButtonStyle())
                
                Button("Apply Skin") {
                    applySkin()
                }
                .buttonStyle(WinampButtonStyle())
            }
        }
        .padding(20)
        .background(.regularMaterial)
    }
    
    private func runPerformanceTest() {
        // Run performance metrics
    }
    
    private func exportComparison() {
        // Export comparison images
    }
    
    private func applySkin() {
        // Apply the converted skin
        dismiss()
    }
}

// MARK: - Skin Display Component
struct SkinDisplayView: View {
    let image: NSImage?
    let title: String
    let showDebugOverlay: Bool
    let showHitTestRegions: Bool
    let isOriginal: Bool
    @Binding var selectedComponent: SkinComponent?
    
    @State private var dragOffset = CGSize.zero
    @State private var scale: CGFloat = 1.0
    @State private var hoveredRegion: HitTestRegion?
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.gradient)
                .aspectRatio(2.7, contentMode: .fit)
            
            // Skin image
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(dragOffset)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(0.5, min(3.0, value))
                                },
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                }
                        )
                    )
            }
            
            // Hit test regions overlay
            if showHitTestRegions {
                HitTestRegionsOverlay(
                    isOriginal: isOriginal,
                    selectedComponent: $selectedComponent,
                    hoveredRegion: $hoveredRegion
                )
            }
            
            // Debug information overlay
            if showDebugOverlay {
                DebugInfoOverlay(
                    image: image,
                    isOriginal: isOriginal,
                    scale: scale,
                    offset: dragOffset
                )
            }
            
            // Title overlay
            VStack {
                Spacer()
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                    Spacer()
                }
                .padding(8)
            }
        }
        .frame(maxWidth: 400, maxHeight: 200)
    }
}

// MARK: - Before/After Slider
struct BeforeAfterSliderView: View {
    let beforeImage: NSImage?
    let afterImage: NSImage?
    let beforeTitle: String
    let afterTitle: String
    let showDebugOverlay: Bool
    let showHitTestRegions: Bool
    @Binding var selectedComponent: SkinComponent?
    
    @State private var sliderPosition: CGFloat = 0.5
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.gradient)
                
                // Before image (full width)
                if let beforeImage = beforeImage {
                    Image(nsImage: beforeImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // After image (clipped)
                if let afterImage = afterImage {
                    Image(nsImage: afterImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .mask(
                            Rectangle()
                                .frame(width: geometry.size.width * sliderPosition)
                                .offset(x: -geometry.size.width * (1 - sliderPosition) / 2)
                        )
                }
                
                // Slider line
                Rectangle()
                    .fill(.white)
                    .frame(width: 2)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .position(x: geometry.size.width * sliderPosition, y: geometry.size.height / 2)
                
                // Slider handle
                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.3), radius: 3)
                    .scaleEffect(isDragging ? 1.2 : 1.0)
                    .position(x: geometry.size.width * sliderPosition, y: geometry.size.height / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let newPosition = value.location.x / geometry.size.width
                                sliderPosition = max(0, min(1, newPosition))
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                
                // Labels
                VStack {
                    HStack {
                        Text(beforeTitle)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                        
                        Spacer()
                        
                        Text(afterTitle)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .padding(8)
                    
                    Spacer()
                }
            }
        }
        .aspectRatio(2.7, contentMode: .fit)
        .frame(maxWidth: 600)
    }
}

// MARK: - Hit Test Regions Overlay
struct HitTestRegionsOverlay: View {
    let isOriginal: Bool
    @Binding var selectedComponent: SkinComponent?
    @Binding var hoveredRegion: HitTestRegion?
    
    // Mock hit test regions
    private let mockRegions: [HitTestRegion] = [
        HitTestRegion(id: "play", type: .button, frame: CGRect(x: 26, y: 88, width: 23, height: 18), component: .playButton),
        HitTestRegion(id: "pause", type: .button, frame: CGRect(x: 54, y: 88, width: 23, height: 18), component: .pauseButton),
        HitTestRegion(id: "stop", type: .button, frame: CGRect(x: 82, y: 88, width: 23, height: 18), component: .stopButton),
        HitTestRegion(id: "volume", type: .slider, frame: CGRect(x: 107, y: 57, width: 68, height: 13), component: .volumeSlider),
        HitTestRegion(id: "position", type: .slider, frame: CGRect(x: 16, y: 72, width: 248, height: 10), component: .positionSlider)
    ]
    
    var body: some View {
        ForEach(mockRegions) { region in
            Rectangle()
                .fill(fillColor(for: region))
                .stroke(strokeColor(for: region), lineWidth: 2)
                .frame(width: region.frame.width, height: region.frame.height)
                .position(
                    x: region.frame.midX,
                    y: region.frame.midY
                )
                .onTapGesture {
                    selectedComponent = region.component
                }
                .onHover { hovering in
                    hoveredRegion = hovering ? region : nil
                }
        }
    }
    
    private func fillColor(for region: HitTestRegion) -> Color {
        if selectedComponent == region.component {
            return .blue.opacity(0.4)
        } else if hoveredRegion?.id == region.id {
            return .yellow.opacity(0.3)
        } else {
            switch region.type {
            case .button:
                return .green.opacity(0.2)
            case .slider:
                return .orange.opacity(0.2)
            case .display:
                return .purple.opacity(0.2)
            }
        }
    }
    
    private func strokeColor(for region: HitTestRegion) -> Color {
        if selectedComponent == region.component {
            return .blue
        } else if hoveredRegion?.id == region.id {
            return .yellow
        } else {
            switch region.type {
            case .button:
                return .green
            case .slider:
                return .orange
            case .display:
                return .purple
            }
        }
    }
}

// MARK: - Debug Info Overlay
struct DebugInfoOverlay: View {
    let image: NSImage?
    let isOriginal: Bool
    let scale: CGFloat
    let offset: CGSize
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug Info")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    if let image = image {
                        Text("Size: \(Int(image.size.width))×\(Int(image.size.height))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    Text("Scale: \(scale, specifier: "%.2f")x")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Text("Platform: \(isOriginal ? "Windows" : "macOS")")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(8)
                .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                
                Spacer()
            }
            .padding(8)
            
            Spacer()
        }
    }
}

// MARK: - Component Detail View
struct ComponentDetailView: View {
    let component: SkinComponent
    
    var body: some View {
        HStack(spacing: 16) {
            // Component icon
            Image(systemName: component.icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            
            // Component details
            VStack(alignment: .leading, spacing: 4) {
                Text(component.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(component.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Conversion status
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                
                Text("Converted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Supporting Types
enum ComparisonMode: String, CaseIterable {
    case sideBySide = "sideBySide"
    case overlay = "overlay"
    case slider = "slider"
    case original = "original"
    case converted = "converted"
}

enum RegionType {
    case button
    case slider
    case display
}

enum SkinComponent: String, CaseIterable {
    case playButton = "playButton"
    case pauseButton = "pauseButton"
    case stopButton = "stopButton"
    case volumeSlider = "volumeSlider"
    case positionSlider = "positionSlider"
    case titleDisplay = "titleDisplay"
    
    var icon: String {
        switch self {
        case .playButton: return "play.fill"
        case .pauseButton: return "pause.fill"
        case .stopButton: return "stop.fill"
        case .volumeSlider: return "speaker.wave.3.fill"
        case .positionSlider: return "timeline.selection"
        case .titleDisplay: return "text.alignleft"
        }
    }
    
    var title: String {
        switch self {
        case .playButton: return "Play Button"
        case .pauseButton: return "Pause Button"
        case .stopButton: return "Stop Button"
        case .volumeSlider: return "Volume Slider"
        case .positionSlider: return "Position Slider"
        case .titleDisplay: return "Title Display"
        }
    }
    
    var description: String {
        switch self {
        case .playButton: return "Starts playback of the current track"
        case .pauseButton: return "Pauses/resumes playback"
        case .stopButton: return "Stops playback and resets position"
        case .volumeSlider: return "Controls audio output volume"
        case .positionSlider: return "Shows and controls playback position"
        case .titleDisplay: return "Shows current track information"
        }
    }
}

struct HitTestRegion: Identifiable {
    let id: String
    let type: RegionType
    let frame: CGRect
    let component: SkinComponent
}