//
//  SkinImportView.swift
//  WinampMac
//
//  Modern skin import interface with drag-and-drop support
//  Features nostalgic design with contemporary UX patterns
//

import SwiftUI
import UniformTypeIdentifiers

@available(macOS 15.0, *)
public struct SkinImportView: View {
    @StateObject private var importManager = SkinImportManager()
    @State private var isDragOver = false
    @State private var showingFileImporter = false
    @State private var animateGradient = false
    @State private var showingPreview = false
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                WinampGradientBackground(animate: animateGradient)
                
                VStack(spacing: 32) {
                    // Header with nostalgic styling
                    WinampHeaderView()
                    
                    // Main import area
                    importArea
                    
                    // Progress section (when importing)
                    if importManager.isImporting {
                        ConversionProgressView(progress: importManager.progress)
                            .transition(.slide)
                    }
                    
                    // Preview section (when ready)
                    if let previewSkin = importManager.previewSkin {
                        SkinPreviewView(skin: previewSkin) {
                            importManager.applySkin()
                        }
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    
                    // Quick actions
                    if !importManager.isImporting {
                        QuickActionsView()
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 32)
            }
            .navigationTitle("Import Winamp Skins")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    animateGradient = true
                }
            }
        }
        .alert("Import Error", isPresented: $importManager.hasError) {
            Button("OK") { importManager.clearError() }
        } message: {
            Text(importManager.errorMessage)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.init("com.nullsoft.winamp.skin")!, .zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importManager.importSkin(from: url)
                }
            case .failure(let error):
                importManager.handleError(error)
            }
        }
    }
    
    private var importArea: some View {
        VStack(spacing: 24) {
            // Main drop zone
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .stroke(strokeGradient, lineWidth: isDragOver ? 3 : 2)
                .frame(height: 280)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial.opacity(isDragOver ? 0.8 : 0.4))
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(isDragOver ? 
                                     Color.green.opacity(0.1) : 
                                     Color.clear)
                        )
                )
                .overlay {
                    VStack(spacing: 20) {
                        // Animated drop icon
                        Image(systemName: isDragOver ? "checkmark.circle.fill" : "arrow.down.circle")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(
                                isDragOver ? 
                                .green.gradient : 
                                .primary.opacity(0.7)
                            )
                            .scaleEffect(isDragOver ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: isDragOver)
                        
                        VStack(spacing: 8) {
                            Text(isDragOver ? "Drop your skin here!" : "Drag & Drop Winamp Skins")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            Text("Supports .wsz files and ZIP archives")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Browse button
                        if !isDragOver {
                            Button("Browse Files") {
                                showingFileImporter = true
                            }
                            .buttonStyle(WinampButtonStyle())
                        }
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                    handleDrop(providers: providers)
                }
                .animation(.easeInOut(duration: 0.2), value: isDragOver)
        }
    }
    
    private var strokeGradient: LinearGradient {
        LinearGradient(
            colors: isDragOver ? 
                [.green, .mint] : 
                [.blue.opacity(0.6), .purple.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, error in
            guard error == nil,
                  let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }
            
            DispatchQueue.main.async {
                importManager.importSkin(from: url)
            }
        }
        
        return true
    }
}

// MARK: - Header Component
struct WinampHeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Winamp-style logo
                Image(systemName: "waveform")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.blue.gradient)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Winamp for macOS")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text("Import your favorite Windows skins")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Progress Component
struct ConversionProgressView: View {
    let progress: SkinImportProgress
    @State private var animateProgress = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Main progress indicator
            VStack(spacing: 12) {
                Text("Converting Skin")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(progress.currentStep.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Progress bar with gradient
            VStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue.gradient)
                        .frame(width: max(0, progress.totalProgress * 300), height: 8)
                        .animation(.easeInOut(duration: 0.3), value: progress.totalProgress)
                }
                .frame(width: 300)
                
                Text("\(Int(progress.totalProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            
            // Step-by-step indicators
            HStack(spacing: 16) {
                ForEach(SkinImportStep.allCases, id: \.self) { step in
                    StepIndicatorView(
                        step: step,
                        isActive: step == progress.currentStep,
                        isComplete: step.rawValue < progress.currentStep.rawValue
                    )
                }
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct StepIndicatorView: View {
    let step: SkinImportStep
    let isActive: Bool
    let isComplete: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 32, height: 32)
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: step.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isActive ? .white : .secondary)
                }
            }
            
            Text(step.shortTitle)
                .font(.caption2)
                .foregroundStyle(isActive ? .primary : .secondary)
                .multilineTextAlignment(.center)
        }
        .scaleEffect(isActive ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isActive)
    }
    
    private var backgroundColor: Color {
        if isComplete { return .green }
        if isActive { return .blue }
        return .quaternary
    }
}

// MARK: - Preview Component
struct SkinPreviewView: View {
    let skin: PreviewSkin
    let onApply: () -> Void
    @State private var showingComparison = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Preview: \(skin.name)")
                .font(.headline)
                .foregroundStyle(.primary)
            
            // Skin preview with before/after toggle
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.8))
                    .frame(height: 200)
                
                if let previewImage = skin.previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Conversion success overlay
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Successfully converted!")
                            .font(.caption)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                    .padding(12)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Compare Original") {
                    showingComparison = true
                }
                .buttonStyle(WinampSecondaryButtonStyle())
                
                Button("Apply Skin") {
                    onApply()
                }
                .buttonStyle(WinampButtonStyle())
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingComparison) {
            SkinComparisonView(skin: skin)
        }
    }
}

// MARK: - Quick Actions
struct QuickActionsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                QuickActionButton(
                    title: "Browse Skins",
                    icon: "folder",
                    color: .blue
                ) {
                    // Open skin browser
                }
                
                QuickActionButton(
                    title: "Download Pack",
                    icon: "arrow.down.circle",
                    color: .green
                ) {
                    // Open skin pack downloader
                }
                
                QuickActionButton(
                    title: "Import Folder",
                    icon: "folder.badge.plus",
                    color: .orange
                ) {
                    // Import entire folder
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(width: 80, height: 60)
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Background Component
struct WinampGradientBackground: View {
    let animate: Bool
    
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, 0.5], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                .blue.opacity(0.3), .purple.opacity(0.2), .blue.opacity(0.3),
                .purple.opacity(0.2), .clear, .purple.opacity(0.2),
                .blue.opacity(0.3), .purple.opacity(0.2), .blue.opacity(0.3)
            ]
        )
        .ignoresSafeArea()
        .opacity(animate ? 0.6 : 0.4)
        .animation(.easeInOut(duration: 3), value: animate)
    }
}

// MARK: - Button Styles
struct WinampButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .fontWeight(.medium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct WinampSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.primary)
            .fontWeight(.medium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Supporting Types
enum SkinImportStep: Int, CaseIterable {
    case extracting = 0
    case parsing = 1
    case converting = 2
    case validating = 3
    case complete = 4
    
    var icon: String {
        switch self {
        case .extracting: return "archivebox"
        case .parsing: return "doc.text"
        case .converting: return "arrow.triangle.2.circlepath"
        case .validating: return "checkmark.shield"
        case .complete: return "checkmark.circle"
        }
    }
    
    var shortTitle: String {
        switch self {
        case .extracting: return "Extract"
        case .parsing: return "Parse"
        case .converting: return "Convert"
        case .validating: return "Validate"
        case .complete: return "Done"
        }
    }
    
    var description: String {
        switch self {
        case .extracting: return "Extracting skin files from archive..."
        case .parsing: return "Reading skin configuration and assets..."
        case .converting: return "Converting images and regions for macOS..."
        case .validating: return "Validating converted skin compatibility..."
        case .complete: return "Skin conversion completed successfully!"
        }
    }
}

struct SkinImportProgress {
    let currentStep: SkinImportStep
    let stepProgress: Double
    
    var totalProgress: Double {
        let baseProgress = Double(currentStep.rawValue) / Double(SkinImportStep.allCases.count - 1)
        let stepContribution = stepProgress / Double(SkinImportStep.allCases.count)
        return min(1.0, baseProgress + stepContribution)
    }
}

struct PreviewSkin {
    let name: String
    let author: String
    let previewImage: NSImage?
    let originalImage: NSImage?
}

// MARK: - Import Manager
@MainActor
class SkinImportManager: ObservableObject {
    @Published var isImporting = false
    @Published var progress = SkinImportProgress(currentStep: .extracting, stepProgress: 0.0)
    @Published var previewSkin: PreviewSkin?
    @Published var hasError = false
    @Published var errorMessage = ""
    
    func importSkin(from url: URL) {
        Task {
            isImporting = true
            previewSkin = nil
            
            do {
                // Simulate conversion process with realistic timing
                for step in SkinImportStep.allCases {
                    guard step != .complete else { break }
                    
                    progress = SkinImportProgress(currentStep: step, stepProgress: 0.0)
                    
                    // Simulate step progress
                    for i in 0...10 {
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        progress = SkinImportProgress(
                            currentStep: step, 
                            stepProgress: Double(i) / 10.0
                        )
                    }
                }
                
                // Complete and show preview
                progress = SkinImportProgress(currentStep: .complete, stepProgress: 1.0)
                
                // Create preview (mock data for now)
                previewSkin = PreviewSkin(
                    name: url.deletingPathExtension().lastPathComponent,
                    author: "Unknown Artist",
                    previewImage: nil, // Would load actual preview
                    originalImage: nil
                )
                
                isImporting = false
                
            } catch {
                handleError(error)
            }
        }
    }
    
    func applySkin() {
        // Apply the converted skin
        previewSkin = nil
    }
    
    func handleError(_ error: Error) {
        isImporting = false
        hasError = true
        errorMessage = error.localizedDescription
    }
    
    func clearError() {
        hasError = false
        errorMessage = ""
    }
}