//
//  SkinDetailView.swift
//  WinampMac
//
//  Detailed skin information and testing interface
//  Features performance metrics and interactive testing
//

import SwiftUI

@available(macOS 15.0, *)
public struct SkinDetailView: View {
    let skin: SkinInfo
    let onApply: (SkinInfo) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var testingManager = SkinTestingManager()
    @State private var selectedTab: DetailTab = .overview
    @State private var showingComparison = false
    @State private var showingPerformanceTest = false
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with preview
                skinHeader
                
                // Tab selector
                Picker("Detail View", selection: $selectedTab) {
                    Text("Overview").tag(DetailTab.overview)
                    Text("Components").tag(DetailTab.components)
                    Text("Performance").tag(DetailTab.performance)
                    Text("Testing").tag(DetailTab.testing)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Tab content
                TabView(selection: $selectedTab) {
                    OverviewTab(skin: skin)
                        .tag(DetailTab.overview)
                    
                    ComponentsTab(skin: skin, testingManager: testingManager)
                        .tag(DetailTab.components)
                    
                    PerformanceTab(testingManager: testingManager)
                        .tag(DetailTab.performance)
                    
                    TestingTab(testingManager: testingManager)
                        .tag(DetailTab.testing)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Action buttons
                actionButtons
            }
            .navigationTitle(skin.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Compare") {
                        showingComparison = true
                    }
                    
                    Menu {
                        Button("Export Skin") {
                            // Export functionality
                        }
                        
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.selectFile(skin.filePath.path, inFileViewerRootedAtPath: "")
                        }
                        
                        Divider()
                        
                        Button("Delete Skin", role: .destructive) {
                            // Delete functionality
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .frame(width: 800, height: 600)
        .sheet(isPresented: $showingComparison) {
            // Comparison view would go here
        }
        .onAppear {
            testingManager.initializeTests(for: skin)
        }
    }
    
    private var skinHeader: some View {
        VStack(spacing: 16) {
            // Large preview
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.gradient)
                    .frame(height: 120)
                
                if let previewImage = skin.previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Text(skin.name)
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Status badges
                VStack {
                    HStack {
                        Spacer()
                        
                        if skin.isActive {
                            Badge(text: "Active", color: .green)
                        }
                        
                        Badge(text: "Converted", color: .blue)
                    }
                    .padding(12)
                    
                    Spacer()
                }
            }
            
            // Skin metadata
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(skin.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        Text("by \(skin.author)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if let lastUsed = skin.lastUsed {
                            Text("Last used \(lastUsed, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("Added \(skin.dateAdded, style: .date)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(20)
        .background(.regularMaterial)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Run Tests") {
                showingPerformanceTest = true
            }
            .buttonStyle(WinampSecondaryButtonStyle())
            
            Button("Compare Original") {
                showingComparison = true
            }
            .buttonStyle(WinampSecondaryButtonStyle())
            
            Spacer()
            
            if skin.isActive {
                Button("Currently Active") {
                    // Already active
                }
                .buttonStyle(WinampDisabledButtonStyle())
                .disabled(true)
            } else {
                Button("Apply Skin") {
                    onApply(skin)
                    dismiss()
                }
                .buttonStyle(WinampButtonStyle())
            }
        }
        .padding(20)
        .background(.regularMaterial)
    }
}

// MARK: - Overview Tab
struct OverviewTab: View {
    let skin: SkinInfo
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Quick stats
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    StatCard(title: "Compatibility", value: "98%", color: .green, icon: "checkmark.shield")
                    StatCard(title: "Performance", value: "Excellent", color: .blue, icon: "speedometer")
                    StatCard(title: "Components", value: "12/14", color: .orange, icon: "cube.box")
                    StatCard(title: "File Size", value: "2.1 MB", color: .purple, icon: "doc")
                }
                
                // Conversion details
                GroupBox("Conversion Details") {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Original Format", value: "Winamp 2.x (.wsz)")
                        DetailRow(label: "Images Converted", value: "14 files")
                        DetailRow(label: "Regions Mapped", value: "47 hit zones")
                        DetailRow(label: "Color Space", value: "sRGB (macOS native)")
                        DetailRow(label: "Transparency", value: "Alpha channel preserved")
                        DetailRow(label: "Animations", value: "2 sequences converted")
                    }
                }
                
                // Supported features
                GroupBox("Feature Support") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        FeatureRow(name: "Main Window", supported: true)
                        FeatureRow(name: "Equalizer", supported: true)
                        FeatureRow(name: "Playlist", supported: true)
                        FeatureRow(name: "Mini Mode", supported: false)
                        FeatureRow(name: "Visualizations", supported: true)
                        FeatureRow(name: "Custom Cursors", supported: false)
                    }
                }
                
                // File information
                GroupBox("File Information") {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Location", value: skin.filePath.lastPathComponent)
                        DetailRow(label: "Date Modified", value: DateFormatter.localizedString(from: skin.dateAdded, dateStyle: .medium, timeStyle: .short))
                        DetailRow(label: "Bundle ID", value: "com.winamp.skin.\(skin.name.lowercased().replacingOccurrences(of: " ", with: "-"))")
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Components Tab
struct ComponentsTab: View {
    let skin: SkinInfo
    let testingManager: SkinTestingManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Component grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(SkinComponent.allCases, id: \.self) { component in
                        ComponentCard(
                            component: component,
                            status: testingManager.componentStatus[component] ?? .unknown
                        ) {
                            testingManager.testComponent(component)
                        }
                    }
                }
                
                // Component details
                if let selectedComponent = testingManager.selectedComponent {
                    ComponentDetailSection(component: selectedComponent)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Performance Tab
struct PerformanceTab: View {
    let testingManager: SkinTestingManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Performance metrics
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    MetricCard(
                        title: "Render Time",
                        value: "\(testingManager.renderTime, specifier: "%.2f") ms",
                        trend: .stable,
                        color: .green
                    )
                    
                    MetricCard(
                        title: "Memory Usage",
                        value: "\(testingManager.memoryUsage, specifier: "%.1f") MB",
                        trend: .down,
                        color: .blue
                    )
                    
                    MetricCard(
                        title: "CPU Usage",
                        value: "\(testingManager.cpuUsage, specifier: "%.1f")%",
                        trend: .stable,
                        color: .orange
                    )
                    
                    MetricCard(
                        title: "GPU Usage",
                        value: "\(testingManager.gpuUsage, specifier: "%.1f")%",
                        trend: .up,
                        color: .purple
                    )
                }
                
                // Performance chart
                GroupBox("Performance Over Time") {
                    PerformanceChartView(metrics: testingManager.performanceHistory)
                        .frame(height: 200)
                }
                
                // Optimization suggestions
                GroupBox("Optimization Suggestions") {
                    VStack(alignment: .leading, spacing: 12) {
                        OptimizationSuggestion(
                            title: "Image Compression",
                            description: "Images could be compressed further to reduce memory usage",
                            impact: .medium,
                            implemented: false
                        )
                        
                        OptimizationSuggestion(
                            title: "Region Simplification",
                            description: "Some hit regions could be simplified for better performance",
                            impact: .low,
                            implemented: true
                        )
                        
                        OptimizationSuggestion(
                            title: "Texture Caching",
                            description: "Implement texture caching for repeated elements",
                            impact: .high,
                            implemented: true
                        )
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Testing Tab
struct TestingTab: View {
    let testingManager: SkinTestingManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Test suite controls
                HStack {
                    Button("Run All Tests") {
                        testingManager.runAllTests()
                    }
                    .buttonStyle(WinampButtonStyle())
                    
                    Button("Reset Tests") {
                        testingManager.resetTests()
                    }
                    .buttonStyle(WinampSecondaryButtonStyle())
                    
                    Spacer()
                    
                    if testingManager.isRunningTests {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Running tests...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Test results
                GroupBox("Test Results") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(testingManager.testResults, id: \.name) { result in
                            TestResultRow(result: result)
                        }
                    }
                }
                
                // Interactive test area
                GroupBox("Interactive Testing") {
                    VStack(spacing: 16) {
                        Text("Click on components to test their functionality")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        InteractiveSkinTester(testingManager: testingManager)
                            .frame(height: 200)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Supporting Components

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color, in: RoundedRectangle(cornerRadius: 4))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .fontWeight(.medium)
        }
    }
}

struct FeatureRow: View {
    let name: String
    let supported: Bool
    
    var body: some View {
        HStack {
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(supported ? .green : .red)
            
            Text(name)
                .foregroundStyle(.primary)
            
            Spacer()
        }
    }
}

struct ComponentCard: View {
    let component: SkinComponent
    let status: ComponentStatus
    let onTest: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: component.icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                
                Spacer()
                
                StatusIndicator(status: status)
            }
            
            Text(component.title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(component.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            
            Button("Test") {
                onTest()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.blue)
        }
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusIndicator: View {
    let status: ComponentStatus
    
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 12, height: 12)
    }
}

struct ComponentDetailSection: View {
    let component: SkinComponent
    
    var body: some View {
        GroupBox("Component Details: \(component.title)") {
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Type", value: "Interactive Element")
                DetailRow(label: "Hit Region", value: "Defined")
                DetailRow(label: "States", value: "Normal, Hover, Pressed")
                DetailRow(label: "Animation", value: "Supported")
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let trend: MetricTrend
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .foregroundStyle(trend.color)
                    .font(.caption)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PerformanceChartView: View {
    let metrics: [PerformanceMetric]
    
    var body: some View {
        // Mock chart implementation
        Rectangle()
            .fill(.quaternary.opacity(0.3))
            .overlay {
                Text("Performance Chart")
                    .foregroundStyle(.secondary)
            }
    }
}

struct OptimizationSuggestion: View {
    let title: String
    let description: String
    let impact: OptimizationImpact
    let implemented: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: implemented ? "checkmark.circle.fill" : "lightbulb")
                .foregroundStyle(implemented ? .green : .yellow)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(impact.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(impact.color, in: RoundedRectangle(cornerRadius: 3))
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct TestResultRow: View {
    let result: TestResult
    
    var body: some View {
        HStack {
            Image(systemName: result.status.icon)
                .foregroundStyle(result.status.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                if let message = result.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if let duration = result.duration {
                Text("\(duration, specifier: "%.0f")ms")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }
}

struct InteractiveSkinTester: View {
    let testingManager: SkinTestingManager
    
    var body: some View {
        // Mock interactive skin tester
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.gradient)
            
            Text("Interactive Skin Preview")
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - Button Style Extensions
struct WinampDisabledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.secondary)
            .fontWeight(.medium)
    }
}

// MARK: - Supporting Types
enum DetailTab: String, CaseIterable {
    case overview = "overview"
    case components = "components"
    case performance = "performance"
    case testing = "testing"
}

enum ComponentStatus {
    case working
    case warning
    case error
    case unknown
    
    var color: Color {
        switch self {
        case .working: return .green
        case .warning: return .yellow
        case .error: return .red
        case .unknown: return .gray
        }
    }
}

enum MetricTrend {
    case up
    case down
    case stable
    
    var icon: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .red
        case .down: return .green
        case .stable: return .gray
        }
    }
}

enum OptimizationImpact: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

enum TestStatus {
    case passed
    case failed
    case warning
    case running
    
    var icon: String {
        switch self {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .running: return "clock"
        }
    }
    
    var color: Color {
        switch self {
        case .passed: return .green
        case .failed: return .red
        case .warning: return .yellow
        case .running: return .blue
        }
    }
}

struct PerformanceMetric {
    let timestamp: Date
    let renderTime: Double
    let memoryUsage: Double
    let cpuUsage: Double
}

struct TestResult {
    let name: String
    let status: TestStatus
    let message: String?
    let duration: Double?
}

// MARK: - Testing Manager
@MainActor
class SkinTestingManager: ObservableObject {
    @Published var componentStatus: [SkinComponent: ComponentStatus] = [:]
    @Published var selectedComponent: SkinComponent?
    @Published var isRunningTests = false
    @Published var testResults: [TestResult] = []
    @Published var performanceHistory: [PerformanceMetric] = []
    
    // Performance metrics
    @Published var renderTime: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var gpuUsage: Double = 0.0
    
    func initializeTests(for skin: SkinInfo) {
        // Initialize testing for the skin
        generateMockData()
    }
    
    func testComponent(_ component: SkinComponent) {
        selectedComponent = component
        componentStatus[component] = .working
    }
    
    func runAllTests() {
        isRunningTests = true
        
        Task {
            // Simulate running tests
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            testResults = [
                TestResult(name: "Hit Region Detection", status: .passed, message: "All regions responsive", duration: 45),
                TestResult(name: "Image Loading", status: .passed, message: "All sprites loaded successfully", duration: 120),
                TestResult(name: "Animation Timing", status: .warning, message: "Minor timing discrepancy", duration: 80),
                TestResult(name: "Memory Leak Check", status: .passed, message: "No leaks detected", duration: 200),
                TestResult(name: "Performance Baseline", status: .passed, message: "Meets performance targets", duration: 300)
            ]
            
            isRunningTests = false
        }
    }
    
    func resetTests() {
        testResults.removeAll()
        componentStatus.removeAll()
        selectedComponent = nil
    }
    
    private func generateMockData() {
        // Generate mock performance data
        renderTime = Double.random(in: 8.0...12.0)
        memoryUsage = Double.random(in: 15.0...25.0)
        cpuUsage = Double.random(in: 2.0...8.0)
        gpuUsage = Double.random(in: 1.0...5.0)
        
        // Initialize component status
        for component in SkinComponent.allCases {
            componentStatus[component] = ComponentStatus.allCases.randomElement() ?? .working
        }
    }
}