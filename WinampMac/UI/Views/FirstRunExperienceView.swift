//
//  FirstRunExperienceView.swift
//  WinampMac
//
//  Onboarding experience for new users
//  Features welcome screen, tutorial, and sample skin installation
//

import SwiftUI

@available(macOS 15.0, *)
public struct FirstRunExperienceView: View {
    @State private var currentStep: OnboardingStep = .welcome
    @State private var isAnimating = false
    @State private var showingSkipConfirmation = false
    @State private var hasDownloadedSamples = false
    @State private var importProgress: Double = 0.0
    
    private let onboardingSteps: [OnboardingStep] = [.welcome, .explanation, .demo, .samples, .complete]
    
    public var body: some View {
        ZStack {
            // Animated background
            WinampOnboardingBackground(animate: isAnimating)
            
            VStack(spacing: 0) {
                // Progress indicator
                progressHeader
                
                // Main content
                TabView(selection: $currentStep) {
                    ForEach(onboardingSteps, id: \.self) { step in
                        stepContent(for: step)
                            .tag(step)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.5), value: currentStep)
                
                // Navigation controls
                navigationControls
            }
        }
        .frame(width: 800, height: 600)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
        .confirmationDialog("Skip Setup?", isPresented: $showingSkipConfirmation) {
            Button("Skip and Start") {
                completeOnboarding()
            }
            Button("Continue Setup") {
                // Stay in onboarding
            }
        } message: {
            Text("You can always import skins later from the main interface.")
        }
    }
    
    private var progressHeader: some View {
        VStack(spacing: 16) {
            // Step indicators
            HStack(spacing: 0) {
                ForEach(Array(onboardingSteps.enumerated()), id: \.offset) { index, step in
                    OnboardingStepIndicator(
                        step: step,
                        isActive: step == currentStep,
                        isComplete: step.rawValue < currentStep.rawValue,
                        isFirst: index == 0,
                        isLast: index == onboardingSteps.count - 1
                    )
                }
            }
            
            // Current step title
            Text(currentStep.title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .animation(.easeInOut, value: currentStep)
        }
        .padding(.top, 32)
        .padding(.bottom, 24)
        .background(.regularMaterial)
    }
    
    @ViewBuilder
    private func stepContent(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStep()
        case .explanation:
            ExplanationStep()
        case .demo:
            DemoStep()
        case .samples:
            SamplesStep(
                hasDownloaded: $hasDownloadedSamples,
                progress: $importProgress
            )
        case .complete:
            CompleteStep()
        }
    }
    
    private var navigationControls: some View {
        HStack(spacing: 16) {
            // Skip button (only on non-final steps)
            if currentStep != .complete {
                Button("Skip Setup") {
                    showingSkipConfirmation = true
                }
                .buttonStyle(WinampSecondaryButtonStyle())
            }
            
            Spacer()
            
            // Back button
            if currentStep != .welcome {
                Button("Back") {
                    withAnimation {
                        moveToStep(currentStep.previous)
                    }
                }
                .buttonStyle(WinampSecondaryButtonStyle())
            }
            
            // Next/Finish button
            Button(currentStep == .complete ? "Get Started" : "Continue") {
                if currentStep == .complete {
                    completeOnboarding()
                } else {
                    withAnimation {
                        moveToStep(currentStep.next)
                    }
                }
            }
            .buttonStyle(WinampButtonStyle())
            .disabled(currentStep == .samples && !hasDownloadedSamples)
        }
        .padding(24)
        .background(.regularMaterial)
    }
    
    private func moveToStep(_ step: OnboardingStep?) {
        guard let step = step else { return }
        currentStep = step
    }
    
    private func completeOnboarding() {
        // Mark onboarding as complete and dismiss
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        // Dismiss view
    }
}

// MARK: - Welcome Step
struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Hero image/animation
            VStack(spacing: 24) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue.gradient)
                    .symbolEffect(.pulse.byLayer, options: .repeating)
                
                VStack(spacing: 12) {
                    Text("Welcome to Winamp for macOS")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Bring your favorite Windows Winamp skins to macOS")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Feature highlights
            VStack(spacing: 16) {
                FeatureHighlight(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Automatic Conversion",
                    description: "Seamlessly convert .wsz skins for macOS"
                )
                
                FeatureHighlight(
                    icon: "paintbrush",
                    title: "Visual Fidelity",
                    description: "Preserves the original look and feel"
                )
                
                FeatureHighlight(
                    icon: "hand.tap",
                    title: "Native Experience",
                    description: "Optimized for macOS interactions"
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 48)
    }
}

// MARK: - Explanation Step
struct ExplanationStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                
                VStack(spacing: 16) {
                    Text("How Skin Conversion Works")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text("""
                    Winamp skins were designed for Windows, but we've built a conversion system that adapts them for macOS while preserving their nostalgic charm.
                    """)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Conversion process visualization
            ConversionProcessView()
            
            // Compatibility note
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Supports Winamp 2.x Classic Skins (.wsz)")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Modern skins and visualizations coming soon")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 48)
    }
}

// MARK: - Demo Step
struct DemoStep: View {
    @State private var selectedSkin: DemoSkin = .classic
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("See the Difference")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("Watch how classic Winamp skins transform for macOS")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Demo skin selector
            Picker("Demo Skin", selection: $selectedSkin) {
                Text("Classic").tag(DemoSkin.classic)
                Text("Metal").tag(DemoSkin.metal)
                Text("Colorful").tag(DemoSkin.colorful)
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            
            // Before/After demo
            HStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Original (Windows)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    SkinDemoView(skin: selectedSkin, variant: .original)
                }
                
                VStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse, options: .repeating)
                    
                    Text("Convert")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 12) {
                    Text("Converted (macOS)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    SkinDemoView(skin: selectedSkin, variant: .converted)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 48)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Samples Step
struct SamplesStep: View {
    @Binding var hasDownloaded: Bool
    @Binding var progress: Double
    @State private var isDownloading = false
    @State private var downloadedSkins: [String] = []
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: hasDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(hasDownloaded ? .green : .blue)
                    .symbolEffect(.bounce, value: hasDownloaded)
                
                Text(hasDownloaded ? "Sample Skins Installed!" : "Download Sample Skins")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(hasDownloaded ? 
                     "You're all set! Try switching between different skins in the main interface." :
                     "Get started with a curated collection of classic Winamp skins that showcase the conversion quality."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            }
            
            if !hasDownloaded {
                // Sample skin grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    ForEach(sampleSkins, id: \.name) { skin in
                        SampleSkinCard(skin: skin, isDownloaded: downloadedSkins.contains(skin.name))
                    }
                }
                .frame(width: 400)
                
                // Download button
                if isDownloading {
                    VStack(spacing: 12) {
                        ProgressView(value: progress)
                            .frame(width: 200)
                        
                        Text("Downloading skins... \(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button("Download Sample Pack (2.5 MB)") {
                        downloadSamples()
                    }
                    .buttonStyle(WinampButtonStyle())
                }
            } else {
                // Success state
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        ForEach(downloadedSkins.prefix(3), id: \.self) { skinName in
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.black.gradient)
                                    .frame(width: 80, height: 30)
                                    .overlay {
                                        Text(skinName)
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    Text("\(downloadedSkins.count) skins ready to use")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 48)
    }
    
    private func downloadSamples() {
        isDownloading = true
        progress = 0.0
        
        Task {
            // Simulate download progress
            for i in 1...100 {
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                await MainActor.run {
                    progress = Double(i) / 100.0
                    
                    // Add skins at certain progress points
                    if i == 30 && !downloadedSkins.contains("Classic") {
                        downloadedSkins.append("Classic")
                    } else if i == 60 && !downloadedSkins.contains("Metal") {
                        downloadedSkins.append("Metal")
                    } else if i == 90 && !downloadedSkins.contains("Retro") {
                        downloadedSkins.append("Retro")
                    }
                }
            }
            
            await MainActor.run {
                downloadedSkins = sampleSkins.map(\.name)
                isDownloading = false
                hasDownloaded = true
            }
        }
    }
    
    private let sampleSkins = [
        SampleSkin(name: "Classic", description: "Original Winamp look", size: "512 KB"),
        SampleSkin(name: "Metal", description: "Brushed metal design", size: "1.2 MB"),
        SampleSkin(name: "Retro", description: "Vintage aesthetic", size: "800 KB")
    ]
}

// MARK: - Complete Step
struct CompleteStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green.gradient)
                    .symbolEffect(.bounce)
                
                VStack(spacing: 12) {
                    Text("You're All Set!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Text("Winamp for macOS is ready to go. Start importing your favorite skins!")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Quick tips
            VStack(spacing: 16) {
                QuickTip(
                    icon: "plus.circle",
                    title: "Import Skins",
                    description: "Drag and drop .wsz files or use the import button"
                )
                
                QuickTip(
                    icon: "eye",
                    title: "Preview Before Applying",
                    description: "See how skins look before making them active"
                )
                
                QuickTip(
                    icon: "square.grid.2x2",
                    title: "Browse Your Collection",
                    description: "Organize and switch between multiple skins easily"
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 48)
    }
}

// MARK: - Supporting Components

struct OnboardingStepIndicator: View {
    let step: OnboardingStep
    let isActive: Bool
    let isComplete: Bool
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Leading line (except for first)
            if !isFirst {
                Rectangle()
                    .fill(isComplete ? .blue : .quaternary)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
            }
            
            // Step circle
            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 32, height: 32)
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(step.rawValue + 1)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isActive ? .white : .secondary)
                }
            }
            .scaleEffect(isActive ? 1.2 : 1.0)
            .animation(.spring(response: 0.3), value: isActive)
            
            // Trailing line (except for last)
            if !isLast {
                Rectangle()
                    .fill(isComplete ? .blue : .quaternary)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var circleColor: Color {
        if isComplete { return .blue }
        if isActive { return .blue }
        return .quaternary
    }
}

struct FeatureHighlight: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(.blue.opacity(0.1), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

struct ConversionProcessView: View {
    var body: some View {
        HStack(spacing: 16) {
            ProcessStep(
                icon: "archivebox",
                title: "Extract",
                description: "Unpack .wsz files"
            )
            
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            
            ProcessStep(
                icon: "arrow.triangle.2.circlepath",
                title: "Convert",
                description: "Adapt for macOS"
            )
            
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            
            ProcessStep(
                icon: "checkmark.circle",
                title: "Apply",
                description: "Ready to use"
            )
        }
        .padding(24)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ProcessStep: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct SkinDemoView: View {
    let skin: DemoSkin
    let variant: SkinVariant
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.gradient)
                .frame(width: 200, height: 74) // Winamp proportions
            
            // Mock skin content based on type
            skinContent
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .shadow(color: .black.opacity(0.2), radius: 4)
    }
    
    @ViewBuilder
    private var skinContent: some View {
        switch skin {
        case .classic:
            Rectangle()
                .fill(variant == .original ? 
                      LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom) :
                      LinearGradient(colors: [.blue.opacity(0.3), .blue.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                )
                .overlay {
                    Text("♪ Winamp")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                
        case .metal:
            Rectangle()
                .fill(variant == .original ?
                      LinearGradient(colors: [.silver, .gray], startPoint: .topLeading, endPoint: .bottomTrailing) :
                      LinearGradient(colors: [.mint.opacity(0.3), .cyan.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay {
                    Text("♪ Metal")
                        .font(.caption)
                        .foregroundStyle(.black)
                }
                
        case .colorful:
            Rectangle()
                .fill(variant == .original ?
                      LinearGradient(colors: [.red, .yellow, .green], startPoint: .leading, endPoint: .trailing) :
                      LinearGradient(colors: [.pink.opacity(0.3), .orange.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                )
                .overlay {
                    Text("♪ Color")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
        }
    }
}

struct SampleSkinCard: View {
    let skin: SampleSkin
    let isDownloaded: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.gradient)
                    .frame(height: 40)
                
                Text(skin.name)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                
                if isDownloaded {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .background(.black.opacity(0.7), in: Circle())
                        }
                        Spacer()
                    }
                    .padding(4)
                }
            }
            
            VStack(spacing: 2) {
                Text(skin.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(skin.size)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct QuickTip: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 32, height: 32)
                .background(.green.opacity(0.1), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

struct WinampOnboardingBackground: View {
    let animate: Bool
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated elements
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(.blue.opacity(0.05))
                    .frame(width: 100, height: 100)
                    .offset(
                        x: animate ? Double.random(in: -200...200) : 0,
                        y: animate ? Double.random(in: -200...200) : 0
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 3...6))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.5),
                        value: animate
                    )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Supporting Types
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case explanation = 1
    case demo = 2
    case samples = 3
    case complete = 4
    
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .explanation: return "How It Works"
        case .demo: return "See It In Action"
        case .samples: return "Get Sample Skins"
        case .complete: return "Ready to Go!"
        }
    }
    
    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
    
    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}

enum DemoSkin: String, CaseIterable {
    case classic = "classic"
    case metal = "metal" 
    case colorful = "colorful"
}

enum SkinVariant {
    case original
    case converted
}

struct SampleSkin {
    let name: String
    let description: String
    let size: String
}