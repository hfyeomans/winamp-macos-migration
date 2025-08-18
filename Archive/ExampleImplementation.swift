import Cocoa
import AVFoundation

// MARK: - Example Implementation
class WinampPlayerApp: NSObject, NSApplicationDelegate {
    
    private var playerWindow: WinampRenderer.SkinWindow?
    private var themeManager: WinampThemeEngine.ThemeManager
    private var audioEngine: AVAudioEngine
    private var audioPlayer: AVAudioPlayerNode
    
    override init() {
        self.themeManager = WinampThemeEngine.ThemeManager.shared
        self.audioEngine = AVAudioEngine()
        self.audioPlayer = AVAudioPlayerNode()
        super.init()
        
        setupAudioEngine()
        setupThemeObserver()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        createPlayerWindow()
        loadDefaultSkin()
    }
    
    // MARK: - Window Creation
    private func createPlayerWindow() {
        playerWindow = WinampRenderer.createExamplePlayer()
        playerWindow?.makeKeyAndOrderFront(nil)
        
        // Add menu for skin selection
        setupMenuBar()
        
        // Setup drag and drop for .wsz files
        setupDragAndDrop()
    }
    
    private func setupMenuBar() {
        let mainMenu = NSMenu()
        
        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(NSMenuItem(title: "About Winamp Player", action: nil, keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // Skins menu
        let skinsMenuItem = NSMenuItem(title: "Skins", action: nil, keyEquivalent: "")
        mainMenu.addItem(skinsMenuItem)
        let skinsMenu = NSMenu(title: "Skins")
        skinsMenuItem.submenu = skinsMenu
        
        skinsMenu.addItem(NSMenuItem(title: "Load Skin...", action: #selector(loadSkinFile), keyEquivalent: "s"))
        skinsMenu.addItem(NSMenuItem(title: "Reload Current Skin", action: #selector(reloadSkin), keyEquivalent: "r"))
        skinsMenu.addItem(NSMenuItem.separator())
        skinsMenu.addItem(NSMenuItem(title: "Built-in Skins", action: nil, keyEquivalent: ""))
        
        // Add built-in skin options
        let builtInSkins = ["Classic", "Matrix", "Deus Ex", "Purple Glow", "Netscape"]
        for skinName in builtInSkins {
            let item = NSMenuItem(title: skinName, action: #selector(loadBuiltInSkin(_:)), keyEquivalent: "")
            item.representedObject = skinName
            skinsMenu.addItem(item)
        }
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    private func setupDragAndDrop() {
        guard let contentView = playerWindow?.contentView else { return }
        
        contentView.registerForDraggedTypes([.fileURL])
        
        // Custom drag handling view
        let dragHandler = DragHandlerView(frame: contentView.bounds)
        dragHandler.onFileDropped = { [weak self] url in
            self?.loadSkinFromURL(url)
        }
        contentView.addSubview(dragHandler)
    }
    
    // MARK: - Audio Setup
    private func setupAudioEngine() {
        audioEngine.attach(audioPlayer)
        audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: nil)
        
        // Install tap for visualization
        let bus = 0
        let bufferSize: UInt32 = 1024
        
        audioEngine.mainMixerNode.installTap(onBus: bus, bufferSize: bufferSize, format: nil) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameCount = Int(buffer.frameLength)
        let spectrumData = performFFT(on: channelData, frameCount: frameCount)
        
        DispatchQueue.main.async { [weak self] in
            self?.updateVisualization(spectrumData)
        }
    }
    
    private func performFFT(on data: UnsafeMutablePointer<Float>, frameCount: Int) -> [Float] {
        // Simplified FFT - in production use Accelerate framework
        var spectrum: [Float] = []
        let binsPerBar = frameCount / 75  // 75 bars like classic Winamp
        
        for i in 0..<75 {
            let startIndex = i * binsPerBar
            let endIndex = min(startIndex + binsPerBar, frameCount)
            
            var sum: Float = 0
            for j in startIndex..<endIndex {
                sum += abs(data[j])
            }
            
            let average = sum / Float(endIndex - startIndex)
            spectrum.append(min(average * 10, 1.0)) // Scale and clamp
        }
        
        return spectrum
    }
    
    private func updateVisualization(_ data: [Float]) {
        // Find visualization view and update it
        findVisualizationView()?.updateSpectrum(data)
    }
    
    private func findVisualizationView() -> WinampRenderer.VisualizationView? {
        guard let contentView = playerWindow?.contentView else { return nil }
        
        for subview in contentView.subviews {
            if let visualization = subview as? WinampRenderer.VisualizationView {
                return visualization
            }
        }
        return nil
    }
    
    // MARK: - Theme Management
    private func setupThemeObserver() {
        themeManager.observeThemeChanges { [weak self] theme in
            self?.applyThemeToWindow(theme)
        }
    }
    
    private func applyThemeToWindow(_ theme: WinampThemeEngine.Theme) {
        guard let window = playerWindow else { return }
        
        // Apply main skin image
        if let mainImage = theme.assets.mainWindow {
            window.applySkin(mainImage)
        }
        
        // Update all themed components
        updateThemedComponents(with: theme)
        
        // Announce theme change
        print("Applied theme: \(theme.metadata.name) by \(theme.metadata.author)")
    }
    
    private func updateThemedComponents(with theme: WinampThemeEngine.Theme) {
        guard let contentView = playerWindow?.contentView else { return }
        
        // Update all theme-aware subviews
        for subview in contentView.subviews {
            if let themedView = subview as? ThemeAware {
                themedView.themeDidChange(theme)
            }
        }
    }
    
    // MARK: - Skin Loading Actions
    @objc private func loadSkinFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType("com.nullsoft.winamp.skin")!, UTType.zip]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        
        openPanel.begin { [weak self] response in
            if response == .OK, let url = openPanel.url {
                self?.loadSkinFromURL(url)
            }
        }
    }
    
    @objc private func reloadSkin() {
        // Reload current theme
        if let currentTheme = themeManager.current {
            applyThemeToWindow(currentTheme)
        }
    }
    
    @objc private func loadBuiltInSkin(_ sender: NSMenuItem) {
        guard let skinName = sender.representedObject as? String else { return }
        
        // Load built-in skin from app bundle
        if let skinURL = Bundle.main.url(forResource: skinName, withExtension: "wsz") {
            loadSkinFromURL(skinURL)
        } else {
            // Show error
            let alert = NSAlert()
            alert.messageText = "Skin Not Found"
            alert.informativeText = "The built-in skin '\(skinName)' could not be found."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    private func loadSkinFromURL(_ url: URL) {
        do {
            try themeManager.loadTheme(from: url)
        } catch {
            // Show error dialog
            let alert = NSAlert()
            alert.messageText = "Failed to Load Skin"
            alert.informativeText = "Could not load skin from \(url.lastPathComponent): \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
    
    private func loadDefaultSkin() {
        // Try to load a default skin from the bundle
        if let defaultSkinURL = Bundle.main.url(forResource: "Classic", withExtension: "wsz") {
            loadSkinFromURL(defaultSkinURL)
        } else {
            // Create a minimal default theme
            createDefaultTheme()
        }
    }
    
    private func createDefaultTheme() {
        // Create a basic theme when no skin is available
        let defaultColors = WinampThemeEngine.ColorScheme(
            primary: NSColor.controlAccentColor,
            secondary: NSColor.secondaryLabelColor,
            background: NSColor.windowBackgroundColor,
            text: NSColor.labelColor,
            accent: NSColor.controlAccentColor,
            visualization: NSColor.systemGreen,
            normalbg: NSColor.controlBackgroundColor,
            normalfg: NSColor.controlTextColor,
            selectbg: NSColor.selectedControlColor,
            selectfg: NSColor.selectedControlTextColor,
            windowbg: NSColor.windowBackgroundColor,
            buttontext: NSColor.controlTextColor,
            scrollbar: NSColor.scrollBarColor,
            listviewbg: NSColor.controlBackgroundColor,
            listviewfg: NSColor.controlTextColor,
            editbg: NSColor.textBackgroundColor,
            editfg: NSColor.textColor
        )
        
        // Apply default colors to current window
        playerWindow?.backgroundColor = defaultColors.background
    }
}

// MARK: - Drag and Drop Handler
class DragHandlerView: NSView {
    var onFileDropped: ((URL) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([.fileURL])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if canAcceptDrag(sender) {
            return .copy
        }
        return []
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = getFileURL(from: sender), canAcceptFile(url) else {
            return false
        }
        
        onFileDropped?(url)
        return true
    }
    
    private func canAcceptDrag(_ sender: NSDraggingInfo) -> Bool {
        guard let url = getFileURL(from: sender) else { return false }
        return canAcceptFile(url)
    }
    
    private func getFileURL(from sender: NSDraggingInfo) -> URL? {
        let pasteboard = sender.draggingPasteboard
        return pasteboard.readObjects(forClasses: [NSURL.self])?.first as? URL
    }
    
    private func canAcceptFile(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        return pathExtension == "wsz" || pathExtension == "zip"
    }
    
    override var isOpaque: Bool { return false }
}

// MARK: - Enhanced Retina Support
extension NSView {
    var retinaScale: CGFloat {
        return window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0
    }
    
    func pixelAlignedFrame(_ frame: NSRect) -> NSRect {
        let scale = retinaScale
        return NSRect(
            x: round(frame.origin.x * scale) / scale,
            y: round(frame.origin.y * scale) / scale,
            width: round(frame.width * scale) / scale,
            height: round(frame.height * scale) / scale
        )
    }
}

// MARK: - Performance Monitoring
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private var frameCount = 0
    private var lastFPSUpdate = CFAbsoluteTimeGetCurrent()
    
    func recordFrame() {
        frameCount += 1
        let now = CFAbsoluteTimeGetCurrent()
        
        if now - lastFPSUpdate >= 1.0 {
            let fps = Double(frameCount) / (now - lastFPSUpdate)
            print("Rendering FPS: \(Int(fps))")
            
            frameCount = 0
            lastFPSUpdate = now
        }
    }
}

// MARK: - Memory Management for Assets
class AssetCache {
    static let shared = AssetCache()
    private var cache: [String: Any] = [:]
    private let cacheQueue = DispatchQueue(label: "asset.cache", attributes: .concurrent)
    
    func store<T>(_ object: T, forKey key: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache[key] = object
        }
    }
    
    func retrieve<T>(forKey key: String, as type: T.Type) -> T? {
        return cacheQueue.sync {
            return cache[key] as? T
        }
    }
    
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    var cacheSize: Int {
        return cacheQueue.sync {
            return cache.count
        }
    }
}

// MARK: - App Delegate Setup
func setupWinampApp() -> WinampPlayerApp {
    return WinampPlayerApp()
}