import Cocoa
import WebKit
import AVFoundation

// MARK: - Winamp macOS Onboarding & Feature Discovery System
// Progressive disclosure onboarding that adapts to user experience level

class WinampOnboardingManager: NSObject {
    
    // MARK: - User Experience Levels
    
    enum UserExperienceLevel {
        case winampVeteran      // Has used Winamp before
        case macOSNative       // Experienced macOS user, new to Winamp
        case casualUser        // General computer user
        case firstTimeUser     // Needs comprehensive guidance
        
        var onboardingDuration: TimeInterval {
            switch self {
            case .winampVeteran: return 30.0      // Quick overview
            case .macOSNative: return 60.0        // Focus on Winamp-specific features
            case .casualUser: return 120.0        // Balanced introduction
            case .firstTimeUser: return 180.0     // Comprehensive walkthrough
            }
        }
        
        var shouldShowAdvancedFeatures: Bool {
            switch self {
            case .winampVeteran, .macOSNative: return true
            default: return false
            }
        }
    }
    
    // MARK: - Onboarding Steps
    
    struct OnboardingStep {
        let id: String
        let title: String
        let description: String
        let content: OnboardingContent
        let targetElement: String?  // CSS selector or view identifier
        let interaction: InteractionType
        let duration: TimeInterval
        let skipable: Bool
        let requiredForCompletion: Bool
        
        enum OnboardingContent {
            case text(String)
            case video(URL)
            case interactive(OnboardingInteraction)
            case animation(OnboardingAnimation)
        }
        
        enum InteractionType {
            case passive            // Just watch/read
            case clickTarget        // Click specific element
            case dragDrop          // Perform drag and drop
            case keyboardShortcut  // Use keyboard shortcut
            case gestureDemo       // Demonstrate gesture
        }
    }
    
    // MARK: - Properties
    
    private var currentStep: Int = 0
    private var onboardingSteps: [OnboardingStep] = []
    private var userExperienceLevel: UserExperienceLevel = .firstTimeUser
    private var onboardingWindow: OnboardingWindow?
    private var overlayController: OnboardingOverlayController?
    private var completedFeatures: Set<String> = []
    
    // MARK: - Onboarding Flow Management
    
    func startOnboarding(for experienceLevel: UserExperienceLevel) {
        userExperienceLevel = experienceLevel
        onboardingSteps = createOnboardingSteps(for: experienceLevel)
        
        // Show welcome screen
        showWelcomeScreen()
    }
    
    private func createOnboardingSteps(for level: UserExperienceLevel) -> [OnboardingStep] {
        var steps: [OnboardingStep] = []
        
        // Core steps for all users
        steps.append(contentsOf: getCoreOnboardingSteps())
        
        // Experience-level specific steps
        switch level {
        case .winampVeteran:
            steps.append(contentsOf: getVeteranSpecificSteps())
        case .macOSNative:
            steps.append(contentsOf: getMacOSNativeSteps())
        case .casualUser:
            steps.append(contentsOf: getCasualUserSteps())
        case .firstTimeUser:
            steps.append(contentsOf: getComprehensiveSteps())
        }
        
        return steps
    }
    
    private func getCoreOnboardingSteps() -> [OnboardingStep] {
        return [
            OnboardingStep(
                id: "welcome",
                title: "Welcome to Winamp for macOS",
                description: "Experience the legendary music player, now perfectly integrated with macOS",
                content: .text("Winamp brings the iconic music experience to macOS with full skin support, advanced audio features, and seamless system integration."),
                targetElement: nil,
                interaction: .passive,
                duration: 3.0,
                skipable: false,
                requiredForCompletion: true
            ),
            
            OnboardingStep(
                id: "main_interface",
                title: "Your Main Player",
                description: "This is where all the magic happens",
                content: .interactive(PlayerInterfaceDemo()),
                targetElement: "main-player-window",
                interaction: .clickTarget,
                duration: 10.0,
                skipable: true,
                requiredForCompletion: true
            ),
            
            OnboardingStep(
                id: "playback_controls",
                title: "Playback Controls",
                description: "Play, pause, stop, and navigate your music",
                content: .animation(PlaybackControlsAnimation()),
                targetElement: "playback-controls",
                interaction: .clickTarget,
                duration: 8.0,
                skipable: true,
                requiredForCompletion: true
            ),
            
            OnboardingStep(
                id: "add_music",
                title: "Adding Music",
                description: "Drag and drop files or folders to add music",
                content: .interactive(DragDropDemo()),
                targetElement: "playlist-area",
                interaction: .dragDrop,
                duration: 15.0,
                skipable: true,
                requiredForCompletion: true
            )
        ]
    }
    
    private func getVeteranSpecificSteps() -> [OnboardingStep] {
        return [
            OnboardingStep(
                id: "skin_differences",
                title: "macOS Skin Enhancements",
                description: "See how classic skins are enhanced for macOS",
                content: .text("Your favorite skins now support Retina displays, ProMotion, and full accessibility features while maintaining their original character."),
                targetElement: nil,
                interaction: .passive,
                duration: 5.0,
                skipable: true,
                requiredForCompletion: false
            ),
            
            OnboardingStep(
                id: "keyboard_shortcuts",
                title: "Familiar Shortcuts",
                description: "Your muscle memory works here too",
                content: .text("Classic Winamp shortcuts work alongside macOS conventions. Press Cmd+K to see all shortcuts."),
                targetElement: nil,
                interaction: .keyboardShortcut,
                duration: 5.0,
                skipable: true,
                requiredForCompletion: false
            )
        ]
    }
    
    private func getMacOSNativeSteps() -> [OnboardingStep] {
        return [
            OnboardingStep(
                id: "what_is_winamp",
                title: "What Makes Winamp Special",
                description: "Discover the features that made Winamp legendary",
                content: .text("Winamp pioneered customizable interfaces (skins), advanced audio processing, and powerful playlist management. Now with full macOS integration."),
                targetElement: nil,
                interaction: .passive,
                duration: 8.0,
                skipable: true,
                requiredForCompletion: false
            ),
            
            OnboardingStep(
                id: "skin_system",
                title: "The Skin System",
                description: "Transform your entire interface",
                content: .interactive(SkinSwitchingDemo()),
                targetElement: "skin-selector",
                interaction: .clickTarget,
                duration: 20.0,
                skipable: true,
                requiredForCompletion: false
            ),
            
            OnboardingStep(
                id: "macos_integration",
                title: "macOS Integration",
                description: "Works seamlessly with your Mac",
                content: .text("Responds to media keys, supports Touch Bar, integrates with Notification Center, and respects all accessibility settings."),
                targetElement: nil,
                interaction: .passive,
                duration: 8.0,
                skipable: true,
                requiredForCompletion: false
            )
        ]
    }
    
    private func getCasualUserSteps() -> [OnboardingStep] {
        return [
            OnboardingStep(
                id: "basic_concepts",
                title: "Music Player Basics",
                description: "Understanding playlists, skins, and audio controls",
                content: .text("Winamp organizes your music in playlists, lets you customize the appearance with skins, and provides professional audio controls."),
                targetElement: nil,
                interaction: .passive,
                duration: 10.0,
                skipable: true,
                requiredForCompletion: false
            ),
            
            OnboardingStep(
                id: "file_management",
                title: "Managing Your Music",
                description: "How to organize and play your audio files",
                content: .interactive(FileManagementDemo()),
                targetElement: "playlist-window",
                interaction: .dragDrop,
                duration: 25.0,
                skipable: true,
                requiredForCompletion: false
            )
        ]
    }
    
    private func getComprehensiveSteps() -> [OnboardingStep] {
        return [
            OnboardingStep(
                id: "computer_audio_basics",
                title: "Digital Music Basics",
                description: "Understanding audio files and playback",
                content: .text("Digital music files store audio in different formats like MP3, FLAC, and AAC. Winamp can play all common formats."),
                targetElement: nil,
                interaction: .passive,
                duration: 12.0,
                skipable: true,
                requiredForCompletion: false
            ),
            
            OnboardingStep(
                id: "interface_tour",
                title: "Complete Interface Tour",
                description: "Every button and feature explained",
                content: .interactive(CompleteInterfaceTour()),
                targetElement: nil,
                interaction: .clickTarget,
                duration: 60.0,
                skipable: true,
                requiredForCompletion: false
            )
        ]
    }
    
    // MARK: - Onboarding Presentation
    
    private func showWelcomeScreen() {
        onboardingWindow = OnboardingWindow(manager: self)
        onboardingWindow?.showWindow(nil)
        onboardingWindow?.displayStep(onboardingSteps[currentStep])
    }
    
    func nextStep() {
        currentStep += 1
        
        if currentStep >= onboardingSteps.count {
            completeOnboarding()
            return
        }
        
        let step = onboardingSteps[currentStep]
        
        if step.targetElement != nil {
            // Show overlay for targeted elements
            showOverlayForStep(step)
        } else {
            // Show in onboarding window
            onboardingWindow?.displayStep(step)
        }
    }
    
    func previousStep() {
        guard currentStep > 0 else { return }
        currentStep -= 1
        
        let step = onboardingSteps[currentStep]
        onboardingWindow?.displayStep(step)
    }
    
    func skipCurrentStep() {
        let step = onboardingSteps[currentStep]
        if step.skipable {
            nextStep()
        }
    }
    
    func skipOnboarding() {
        completeOnboarding()
    }
    
    private func showOverlayForStep(_ step: OnboardingStep) {
        guard let targetElement = step.targetElement else {
            onboardingWindow?.displayStep(step)
            return
        }
        
        // Find target window and element
        if let targetWindow = findWindowContaining(targetElement) {
            overlayController = OnboardingOverlayController(
                window: targetWindow,
                targetElement: targetElement,
                step: step,
                manager: self
            )
            overlayController?.show()
        }
    }
    
    private func findWindowContaining(_ elementId: String) -> NSWindow? {
        // Implementation to find window containing target element
        return NSApp.windows.first { window in
            // Check if window contains the target element
            return true  // Simplified for example
        }
    }
    
    private func completeOnboarding() {
        // Save completion status
        UserDefaults.standard.set(true, forKey: "OnboardingCompleted")
        UserDefaults.standard.set(Date(), forKey: "OnboardingCompletedDate")
        
        // Close onboarding windows
        onboardingWindow?.close()
        overlayController?.hide()
        
        // Show completion message
        showOnboardingCompletionMessage()
        
        // Start feature discovery system
        startFeatureDiscovery()
    }
    
    private func showOnboardingCompletionMessage() {
        let alert = NSAlert()
        alert.messageText = "Welcome Aboard!"
        alert.informativeText = "You're all set to enjoy Winamp on macOS. Remember, you can access help anytime from the Help menu."
        alert.addButton(withTitle: "Start Playing Music")
        alert.runModal()
    }
}

// MARK: - Feature Discovery System

extension WinampOnboardingManager {
    
    private func startFeatureDiscovery() {
        // Schedule contextual feature discoveries
        scheduleFeatureDiscovery()
    }
    
    private func scheduleFeatureDiscovery() {
        let discoveries = [
            FeatureDiscovery(
                feature: "shaded_mode",
                trigger: .titleBarDoubleClick,
                delay: 30.0,
                hint: "💡 Try double-clicking the title bar to enter shaded mode!"
            ),
            
            FeatureDiscovery(
                feature: "equalizer",
                trigger: .playingMusic(duration: 60.0),
                delay: 10.0,
                hint: "🎵 Want better sound? Open the equalizer with Cmd+E"
            ),
            
            FeatureDiscovery(
                feature: "visualizations",
                trigger: .playingMusic(duration: 120.0),
                delay: 15.0,
                hint: "✨ See your music! Try the visualizer with Cmd+V"
            ),
            
            FeatureDiscovery(
                feature: "skin_switching",
                trigger: .rightClickOnPlayer,
                delay: 5.0,
                hint: "🎨 Right-click to explore different skins and themes"
            )
        ]
        
        for discovery in discoveries {
            scheduleDiscovery(discovery)
        }
    }
    
    private func scheduleDiscovery(_ discovery: FeatureDiscovery) {
        discovery.trigger.observe { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + discovery.delay) {
                self?.showFeatureHint(discovery)
            }
        }
    }
    
    private func showFeatureHint(_ discovery: FeatureDiscovery) {
        guard !completedFeatures.contains(discovery.feature) else { return }
        
        let hint = FeatureHintController(discovery: discovery)
        hint.show { [weak self] completed in
            if completed {
                self?.completedFeatures.insert(discovery.feature)
            }
        }
    }
}

// MARK: - Onboarding Window

class OnboardingWindow: NSWindowController {
    
    private weak var manager: WinampOnboardingManager?
    private var webView: WKWebView!
    private var currentStep: OnboardingStep?
    
    init(manager: WinampOnboardingManager) {
        self.manager = manager
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        setupWindow()
        setupWebView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        window?.title = "Welcome to Winamp"
        window?.center()
        window?.level = .floating
        window?.isReleasedWhenClosed = false
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: "onboarding")
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        
        window?.contentView = webView
    }
    
    func displayStep(_ step: OnboardingStep) {
        currentStep = step
        
        let html = generateStepHTML(step)
        webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
    }
    
    private func generateStepHTML(_ step: OnboardingStep) -> String {
        let template = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(step.title)</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    margin: 0;
                    padding: 40px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    min-height: 100vh;
                    box-sizing: border-box;
                }
                
                .container {
                    max-width: 500px;
                    margin: 0 auto;
                    text-align: center;
                }
                
                h1 {
                    font-size: 2.5em;
                    margin-bottom: 20px;
                    text-shadow: 0 2px 4px rgba(0,0,0,0.3);
                }
                
                .description {
                    font-size: 1.2em;
                    margin-bottom: 30px;
                    opacity: 0.9;
                }
                
                .content {
                    background: rgba(255,255,255,0.1);
                    padding: 30px;
                    border-radius: 15px;
                    margin-bottom: 40px;
                    backdrop-filter: blur(10px);
                }
                
                .navigation {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                }
                
                button {
                    background: rgba(255,255,255,0.2);
                    border: none;
                    padding: 12px 24px;
                    border-radius: 25px;
                    color: white;
                    font-size: 16px;
                    cursor: pointer;
                    transition: all 0.3s ease;
                    backdrop-filter: blur(10px);
                }
                
                button:hover {
                    background: rgba(255,255,255,0.3);
                    transform: translateY(-2px);
                }
                
                button:disabled {
                    opacity: 0.5;
                    cursor: not-allowed;
                }
                
                .primary {
                    background: rgba(255,255,255,0.9);
                    color: #333;
                }
                
                .skip {
                    text-decoration: underline;
                    background: none;
                    opacity: 0.7;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>\(step.title)</h1>
                <div class="description">\(step.description)</div>
                
                <div class="content">
                    \(generateContentHTML(step.content))
                </div>
                
                <div class="navigation">
                    <button onclick="window.webkit.messageHandlers.onboarding.postMessage({action: 'previous'})" \(currentStep == 0 ? "disabled" : "")>
                        Previous
                    </button>
                    
                    <div>
                        \(step.skipable ? "<button class=\"skip\" onclick=\"window.webkit.messageHandlers.onboarding.postMessage({action: 'skip'})\">Skip</button>" : "")
                    </div>
                    
                    <button class="primary" onclick="window.webkit.messageHandlers.onboarding.postMessage({action: 'next'})">
                        Next
                    </button>
                </div>
            </div>
            
            <script>
                // Auto-advance timer if duration is set
                \(step.duration > 0 ? "setTimeout(() => { window.webkit.messageHandlers.onboarding.postMessage({action: 'next'}); }, \(step.duration * 1000));" : "")
            </script>
        </body>
        </html>
        """
        
        return template
    }
    
    private func generateContentHTML(_ content: OnboardingStep.OnboardingContent) -> String {
        switch content {
        case .text(let text):
            return "<p>\(text)</p>"
        case .video(let url):
            return "<video controls width=\"100%\" src=\"\(url.absoluteString)\"></video>"
        case .interactive(let interaction):
            return interaction.generateHTML()
        case .animation(let animation):
            return animation.generateHTML()
        }
    }
}

// MARK: - WebView Delegate

extension OnboardingWindow: WKScriptMessageHandler, WKNavigationDelegate {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        
        switch action {
        case "next":
            manager?.nextStep()
        case "previous":
            manager?.previousStep()
        case "skip":
            manager?.skipCurrentStep()
        case "skipAll":
            manager?.skipOnboarding()
        default:
            break
        }
    }
}

// MARK: - Onboarding Content Types

protocol OnboardingInteraction {
    func generateHTML() -> String
}

protocol OnboardingAnimation {
    func generateHTML() -> String
}

struct PlayerInterfaceDemo: OnboardingInteraction {
    func generateHTML() -> String {
        return """
        <div class="player-demo">
            <div class="demo-player" style="background: #333; padding: 20px; border-radius: 10px; margin: 20px 0;">
                <div style="display: flex; align-items: center; justify-content: center;">
                    <button style="margin: 0 10px;">⏮</button>
                    <button style="margin: 0 10px; font-size: 1.5em;">⏯</button>
                    <button style="margin: 0 10px;">⏭</button>
                </div>
                <div style="margin-top: 15px; text-align: center;">
                    <div style="background: #555; height: 4px; border-radius: 2px; margin: 10px 0;">
                        <div style="background: #4CAF50; height: 100%; width: 30%; border-radius: 2px;"></div>
                    </div>
                    <small>Now Playing: Llama - Track.mp3</small>
                </div>
            </div>
            <p>Click the play button to start your first track!</p>
        </div>
        """
    }
}

struct PlaybackControlsAnimation: OnboardingAnimation {
    func generateHTML() -> String {
        return """
        <div class="controls-animation">
            <style>
                .control-highlight {
                    animation: pulse 2s infinite;
                    border: 2px solid #FFD700;
                    border-radius: 50%;
                }
                
                @keyframes pulse {
                    0% { transform: scale(1); opacity: 1; }
                    50% { transform: scale(1.1); opacity: 0.7; }
                    100% { transform: scale(1); opacity: 1; }
                }
            </style>
            
            <div style="display: flex; justify-content: center; align-items: center; margin: 20px 0;">
                <button class="control-highlight" style="margin: 0 5px; padding: 10px;">⏮</button>
                <button style="margin: 0 5px; padding: 10px;">⏸</button>
                <button style="margin: 0 5px; padding: 10px;">⏹</button>
                <button style="margin: 0 5px; padding: 10px;">⏭</button>
            </div>
            
            <p>Previous • Play/Pause • Stop • Next</p>
        </div>
        """
    }
}

struct DragDropDemo: OnboardingInteraction {
    func generateHTML() -> String {
        return """
        <div class="dragdrop-demo">
            <div style="border: 2px dashed rgba(255,255,255,0.5); padding: 40px; border-radius: 10px; margin: 20px 0;">
                <div style="text-align: center; opacity: 0.7;">
                    📁 Drop music files here
                </div>
            </div>
            <p>Drag audio files from Finder and drop them into the playlist area to add them to your library.</p>
        </div>
        """
    }
}

struct SkinSwitchingDemo: OnboardingInteraction {
    func generateHTML() -> String {
        return """
        <div class="skin-demo">
            <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin: 20px 0;">
                <div style="background: linear-gradient(45deg, #ff6b6b, #feca57); height: 60px; border-radius: 5px; display: flex; align-items: center; justify-content: center; color: white; font-weight: bold;">Classic</div>
                <div style="background: linear-gradient(45deg, #48dbfb, #0abde3); height: 60px; border-radius: 5px; display: flex; align-items: center; justify-content: center; color: white; font-weight: bold;">Modern</div>
                <div style="background: linear-gradient(45deg, #ff9ff3, #f368e0); height: 60px; border-radius: 5px; display: flex; align-items: center; justify-content: center; color: white; font-weight: bold;">Neon</div>
            </div>
            <p>Right-click on the player window to access the skin menu and completely transform your interface!</p>
        </div>
        """
    }
}

struct FileManagementDemo: OnboardingInteraction {
    func generateHTML() -> String {
        return """
        <div class="file-management">
            <div style="background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px;">
                <h4>Supported File Types:</h4>
                <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin: 10px 0;">
                    <span style="background: rgba(255,255,255,0.2); padding: 5px; border-radius: 3px; text-align: center;">MP3</span>
                    <span style="background: rgba(255,255,255,0.2); padding: 5px; border-radius: 3px; text-align: center;">FLAC</span>
                    <span style="background: rgba(255,255,255,0.2); padding: 5px; border-radius: 3px; text-align: center;">AAC</span>
                    <span style="background: rgba(255,255,255,0.2); padding: 5px; border-radius: 3px; text-align: center;">WAV</span>
                </div>
            </div>
            <p>Drag entire folders to automatically add all supported audio files. Winamp will organize them in your playlist.</p>
        </div>
        """
    }
}

struct CompleteInterfaceTour: OnboardingInteraction {
    func generateHTML() -> String {
        return """
        <div class="interface-tour">
            <p>This interactive tour will highlight each part of the interface and explain its function.</p>
            <div style="background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px; margin: 20px 0;">
                <h4>Tour Includes:</h4>
                <ul style="text-align: left;">
                    <li>Main player controls</li>
                    <li>Volume and balance controls</li>
                    <li>Time display and seek bar</li>
                    <li>Playlist management</li>
                    <li>Equalizer access</li>
                    <li>Visualization options</li>
                    <li>Menu system</li>
                </ul>
            </div>
            <p><strong>This tour takes about 2 minutes to complete.</strong></p>
        </div>
        """
    }
}

// MARK: - Feature Discovery

struct FeatureDiscovery {
    let feature: String
    let trigger: DiscoveryTrigger
    let delay: TimeInterval
    let hint: String
}

enum DiscoveryTrigger {
    case titleBarDoubleClick
    case playingMusic(duration: TimeInterval)
    case rightClickOnPlayer
    case firstPlaylistCreated
    case volumeAdjustment
    
    func observe(callback: @escaping () -> Void) {
        // Implementation would observe for the specific trigger
        // This is simplified for the example
    }
}

class FeatureHintController {
    private let discovery: FeatureDiscovery
    private var hintWindow: NSWindow?
    
    init(discovery: FeatureDiscovery) {
        self.discovery = discovery
    }
    
    func show(completion: @escaping (Bool) -> Void) {
        // Create and show feature hint popup
        // Implementation would create a small, non-intrusive hint window
    }
}