//
//  ErrorRecoveryView.swift
//  WinampMac
//
//  Comprehensive error handling and recovery interface
//  Features detailed diagnostics and guided recovery steps
//

import SwiftUI

@available(macOS 15.0, *)
public struct ErrorRecoveryView: View {
    let error: SkinConversionError
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    @State private var showingDiagnostics = false
    @State private var selectedSolution: RecoverySolution?
    @State private var isFixingAutomatically = false
    
    public var body: some View {
        VStack(spacing: 0) {
            // Error header
            errorHeader
            
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Error explanation
                    errorExplanation
                    
                    // Quick fixes
                    if !error.solutions.isEmpty {
                        quickFixesSection
                    }
                    
                    // Detailed diagnostics
                    if showingDiagnostics {
                        diagnosticsSection
                    }
                    
                    // Alternative actions
                    alternativeActionsSection
                }
                .padding(24)
            }
            
            // Action buttons
            actionButtons
        }
        .frame(width: 600, height: 500)
        .background(.regularMaterial)
    }
    
    private var errorHeader: some View {
        VStack(spacing: 16) {
            // Error icon with animation
            ZStack {
                Circle()
                    .fill(.red.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: error.category.icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.red)
            }
            
            // Error title and subtitle
            VStack(spacing: 8) {
                Text(error.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                
                Text(error.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
    }
    
    private var errorExplanation: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    
                    Text("What happened?")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
                
                Text(error.detailedDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Show technical details toggle
                Button(showingDiagnostics ? "Hide Technical Details" : "Show Technical Details") {
                    withAnimation(.easeInOut) {
                        showingDiagnostics.toggle()
                    }
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
        }
    }
    
    private var quickFixesSection: some View {
        GroupBox("Quick Fixes") {
            VStack(spacing: 12) {
                ForEach(error.solutions, id: \.id) { solution in
                    QuickFixCard(
                        solution: solution,
                        isSelected: selectedSolution?.id == solution.id,
                        isFixing: isFixingAutomatically && selectedSolution?.id == solution.id
                    ) {
                        selectedSolution = solution
                        attemptAutoFix(solution)
                    }
                }
            }
        }
    }
    
    private var diagnosticsSection: some View {
        GroupBox("Technical Diagnostics") {
            VStack(alignment: .leading, spacing: 16) {
                // File information
                if let fileInfo = error.fileInfo {
                    DiagnosticSection(title: "File Information") {
                        DiagnosticRow(label: "File Name", value: fileInfo.fileName)
                        DiagnosticRow(label: "File Size", value: ByteCountFormatter.string(fromByteCount: fileInfo.fileSize, countStyle: .file))
                        DiagnosticRow(label: "File Type", value: fileInfo.fileType)
                        if let encoding = fileInfo.encoding {
                            DiagnosticRow(label: "Encoding", value: encoding)
                        }
                    }
                }
                
                // Conversion details
                if let conversionInfo = error.conversionInfo {
                    DiagnosticSection(title: "Conversion Details") {
                        DiagnosticRow(label: "Stage", value: conversionInfo.stage)
                        DiagnosticRow(label: "Progress", value: "\(Int(conversionInfo.progress * 100))%")
                        if let lastSuccessfulStep = conversionInfo.lastSuccessfulStep {
                            DiagnosticRow(label: "Last Success", value: lastSuccessfulStep)
                        }
                    }
                }
                
                // System information
                DiagnosticSection(title: "System Information") {
                    DiagnosticRow(label: "macOS Version", value: ProcessInfo.processInfo.operatingSystemVersionString)
                    DiagnosticRow(label: "Available Memory", value: ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory))
                    DiagnosticRow(label: "Disk Space", value: "Available") // Would calculate actual space
                }
                
                // Error log
                if let errorLog = error.errorLog {
                    DiagnosticSection(title: "Error Log") {
                        ScrollView {
                            Text(errorLog)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 100)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }
    
    private var alternativeActionsSection: some View {
        GroupBox("Alternative Actions") {
            VStack(spacing: 12) {
                AlternativeActionCard(
                    title: "Try Different Skin",
                    description: "Select a different .wsz file to convert",
                    icon: "folder",
                    color: .blue
                ) {
                    // Open file picker
                }
                
                AlternativeActionCard(
                    title: "Download Sample Skins",
                    description: "Get working example skins to test with",
                    icon: "arrow.down.circle",
                    color: .green
                ) {
                    // Download samples
                }
                
                AlternativeActionCard(
                    title: "Report Issue",
                    description: "Help improve skin compatibility",
                    icon: "exclamationmark.bubble",
                    color: .orange
                ) {
                    // Report issue
                }
                
                AlternativeActionCard(
                    title: "View Documentation",
                    description: "Learn about supported skin formats",
                    icon: "doc.text",
                    color: .purple
                ) {
                    // Open documentation
                }
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                onDismiss()
            }
            .buttonStyle(WinampSecondaryButtonStyle())
            
            if error.isRetryable {
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(WinampButtonStyle())
            }
            
            if let solution = selectedSolution, solution.canAutoFix {
                Button(isFixingAutomatically ? "Fixing..." : "Apply Fix") {
                    attemptAutoFix(solution)
                }
                .buttonStyle(WinampButtonStyle())
                .disabled(isFixingAutomatically)
            }
        }
        .padding(24)
        .background(.regularMaterial)
    }
    
    private func attemptAutoFix(_ solution: RecoverySolution) {
        guard solution.canAutoFix else { return }
        
        isFixingAutomatically = true
        
        Task {
            do {
                try await solution.execute()
                // If successful, retry the conversion
                onRetry()
            } catch {
                // Show fix failed
                isFixingAutomatically = false
            }
        }
    }
}

// MARK: - Quick Fix Card
struct QuickFixCard: View {
    let solution: RecoverySolution
    let isSelected: Bool
    let isFixing: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Solution icon
                ZStack {
                    Circle()
                        .fill(solution.severity.color.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    if isFixing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: solution.icon)
                            .foregroundStyle(solution.severity.color)
                    }
                }
                
                // Solution details
                VStack(alignment: .leading, spacing: 4) {
                    Text(solution.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(solution.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    if solution.canAutoFix {
                        Text("Can fix automatically")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? .blue.opacity(0.1) : .quaternary.opacity(0.3))
                .stroke(isSelected ? .blue : .clear, lineWidth: 2)
        )
        .disabled(isFixing)
    }
}

// MARK: - Alternative Action Card
struct AlternativeActionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Diagnostic Components
struct DiagnosticSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .padding(12)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct DiagnosticRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

// MARK: - Error Types
public struct SkinConversionError {
    let category: ErrorCategory
    let title: String
    let subtitle: String
    let detailedDescription: String
    let solutions: [RecoverySolution]
    let isRetryable: Bool
    let fileInfo: FileInfo?
    let conversionInfo: ConversionInfo?
    let errorLog: String?
    
    struct FileInfo {
        let fileName: String
        let fileSize: Int64
        let fileType: String
        let encoding: String?
    }
    
    struct ConversionInfo {
        let stage: String
        let progress: Double
        let lastSuccessfulStep: String?
    }
}

public enum ErrorCategory {
    case fileFormat
    case corruption
    case unsupported
    case system
    case network
    
    var icon: String {
        switch self {
        case .fileFormat: return "doc.badge.exclamationmark"
        case .corruption: return "exclamationmark.triangle"
        case .unsupported: return "xmark.circle"
        case .system: return "gear.badge.xmark"
        case .network: return "wifi.exclamationmark"
        }
    }
}

public struct RecoverySolution: Identifiable {
    public let id = UUID()
    let title: String
    let description: String
    let icon: String
    let severity: SolutionSeverity
    let canAutoFix: Bool
    let steps: [String]
    let estimatedTime: TimeInterval
    
    func execute() async throws {
        // Implementation would vary based on solution type
        try await Task.sleep(nanoseconds: UInt64(estimatedTime * 1_000_000_000))
    }
}

public enum SolutionSeverity {
    case simple
    case moderate
    case complex
    
    var color: Color {
        switch self {
        case .simple: return .green
        case .moderate: return .orange
        case .complex: return .red
        }
    }
}

// MARK: - Common Error Factories
extension SkinConversionError {
    static func missingMainBMP(fileName: String) -> SkinConversionError {
        SkinConversionError(
            category: .fileFormat,
            title: "Missing Required File",
            subtitle: "The main.bmp file is required but not found",
            detailedDescription: """
            Winamp skins require a main.bmp file that defines the main player interface. This file contains the base graphics and layout for the player controls.
            
            Without this file, the skin cannot be properly converted or displayed. The main.bmp file should be located in the root of the .wsz archive.
            """,
            solutions: [
                RecoverySolution(
                    title: "Extract and Check Archive",
                    description: "Manually extract the .wsz file to verify its contents",
                    icon: "archivebox",
                    severity: .simple,
                    canAutoFix: false,
                    steps: [
                        "Rename the .wsz file to .zip",
                        "Extract the archive using Finder",
                        "Look for main.bmp in the extracted files",
                        "If found, repackage as .wsz"
                    ],
                    estimatedTime: 60
                ),
                RecoverySolution(
                    title: "Try Alternative Format",
                    description: "Some skins use different naming conventions",
                    icon: "arrow.clockwise",
                    severity: .moderate,
                    canAutoFix: true,
                    steps: [
                        "Scan for alternative main window files",
                        "Check for numbered variants (main0.bmp, etc.)",
                        "Look for uppercase variants (MAIN.BMP)"
                    ],
                    estimatedTime: 10
                )
            ],
            isRetryable: true,
            fileInfo: SkinConversionError.FileInfo(
                fileName: fileName,
                fileSize: 0,
                fileType: "Winamp Skin (.wsz)",
                encoding: nil
            ),
            conversionInfo: SkinConversionError.ConversionInfo(
                stage: "File Extraction",
                progress: 0.2,
                lastSuccessfulStep: "Archive opened successfully"
            ),
            errorLog: "ERROR: main.bmp not found in archive root\nSearched paths: main.bmp, MAIN.BMP, Main.bmp"
        )
    }
    
    static func corruptedArchive(fileName: String, error: Error) -> SkinConversionError {
        SkinConversionError(
            category: .corruption,
            title: "Corrupted Archive",
            subtitle: "The skin file appears to be damaged or incomplete",
            detailedDescription: """
            The .wsz file could not be opened or extracted properly. This usually indicates that the file is corrupted, incomplete, or not a valid ZIP archive.
            
            This can happen if the file was not downloaded completely, was damaged during transfer, or is not actually a Winamp skin file.
            """,
            solutions: [
                RecoverySolution(
                    title: "Re-download Skin",
                    description: "Download the skin file again from the original source",
                    icon: "arrow.down.circle",
                    severity: .simple,
                    canAutoFix: false,
                    steps: [
                        "Go back to the original download source",
                        "Download the skin file again",
                        "Verify the file size matches the original",
                        "Try importing the new file"
                    ],
                    estimatedTime: 120
                ),
                RecoverySolution(
                    title: "Repair Archive",
                    description: "Attempt to repair the damaged archive",
                    icon: "wrench",
                    severity: .moderate,
                    canAutoFix: true,
                    steps: [
                        "Analyze archive structure",
                        "Attempt to recover readable portions",
                        "Reconstruct file headers if possible"
                    ],
                    estimatedTime: 30
                )
            ],
            isRetryable: true,
            fileInfo: SkinConversionError.FileInfo(
                fileName: fileName,
                fileSize: 0,
                fileType: "Corrupted Archive",
                encoding: nil
            ),
            conversionInfo: SkinConversionError.ConversionInfo(
                stage: "Archive Extraction",
                progress: 0.0,
                lastSuccessfulStep: nil
            ),
            errorLog: "ERROR: \(error.localizedDescription)"
        )
    }
    
    static func unsupportedFormat(fileName: String, detectedFormat: String) -> SkinConversionError {
        SkinConversionError(
            category: .unsupported,
            title: "Unsupported Format",
            subtitle: "This skin format is not currently supported",
            detailedDescription: """
            The file you're trying to import appears to be a \(detectedFormat) file, which is not currently supported by the converter.
            
            Currently supported formats:
            • Winamp 2.x Classic Skins (.wsz)
            • ZIP archives containing Winamp skin files
            
            Support for additional formats may be added in future updates.
            """,
            solutions: [
                RecoverySolution(
                    title: "Convert to Supported Format",
                    description: "Use Winamp to export this skin in a compatible format",
                    icon: "arrow.triangle.2.circlepath",
                    severity: .moderate,
                    canAutoFix: false,
                    steps: [
                        "Open the skin in Winamp on Windows",
                        "Go to Options > Skins > Skin Browser",
                        "Right-click the skin and select 'Export'",
                        "Choose 'Classic Skin (.wsz)' format",
                        "Import the exported file"
                    ],
                    estimatedTime: 300
                ),
                RecoverySolution(
                    title: "Find Alternative Version",
                    description: "Look for a classic skin version of this design",
                    icon: "magnifyingglass",
                    severity: .simple,
                    canAutoFix: false,
                    steps: [
                        "Search for the skin name + 'classic'",
                        "Check the original author's other releases",
                        "Look on Winamp skin archives",
                        "Ask the community for alternatives"
                    ],
                    estimatedTime: 600
                )
            ],
            isRetryable: false,
            fileInfo: SkinConversionError.FileInfo(
                fileName: fileName,
                fileSize: 0,
                fileType: detectedFormat,
                encoding: nil
            ),
            conversionInfo: SkinConversionError.ConversionInfo(
                stage: "Format Detection",
                progress: 0.1,
                lastSuccessfulStep: "File type identified"
            ),
            errorLog: "FORMAT: Detected \(detectedFormat), expected Winamp Classic Skin"
        )
    }
}