//
//  WinampLite - Minimal Working Winamp Player for macOS
//  A simplified version that demonstrates skin loading and basic playback
//

import AppKit
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Main App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow!
    var skinWindow: SkinWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainWindow()
        loadDefaultSkin()
        
        // Setup menu
        setupMenu()
    }
    
    func setupMainWindow() {
        skinWindow = SkinWindow()
        skinWindow.makeKeyAndOrderFront(nil)
        mainWindow = skinWindow
    }
    
    func loadDefaultSkin() {
        // Try to load first available skin
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(atPath: fm.currentDirectoryPath) {
            if let firstSkin = contents.first(where: { $0.hasSuffix(".wsz") }) {
                let url = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent(firstSkin)
                skinWindow.loadSkin(from: url)
            }
        }
    }
    
    func setupMenu() {
        let mainMenu = NSMenu()
        
        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About WinampLite", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        
        // File menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "Open Skin...", action: #selector(openSkin), keyEquivalent: "o"))
        fileMenu.addItem(NSMenuItem(title: "Open Audio...", action: #selector(openAudio), keyEquivalent: "a"))
        fileMenuItem.submenu = fileMenu
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "WinampLite for macOS"
        alert.informativeText = "A minimal Winamp skin player\nConverts .wsz skins to work on macOS"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func openSkin() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "wsz")!]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.skinWindow.loadSkin(from: url)
            }
        }
    }
    
    @objc func openAudio() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .mp3]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                AudioPlayer.shared.play(url: url)
            }
        }
    }
}

// MARK: - Skin Window

class SkinWindow: NSWindow {
    private var skinImageView: NSImageView!
    private var controlsView: ControlsView!
    private var extractedSkinPath: URL?
    
    init() {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 275, height: 116),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        title = "WinampLite"
        isMovableByWindowBackground = true
        
        setupViews()
    }
    
    func setupViews() {
        // Background image view
        skinImageView = NSImageView(frame: contentView!.bounds)
        skinImageView.imageScaling = .scaleNone
        skinImageView.autoresizingMask = [.width, .height]
        contentView?.addSubview(skinImageView)
        
        // Controls overlay
        controlsView = ControlsView(frame: contentView!.bounds)
        controlsView.autoresizingMask = [.width, .height]
        contentView?.addSubview(controlsView)
    }
    
    func loadSkin(from url: URL) {
        print("Loading skin: \(url.lastPathComponent)")
        
        // Extract skin
        if let extracted = extractSkin(from: url) {
            extractedSkinPath = extracted
            
            // Load main.bmp
            var mainBmpPaths = [
                extracted.appendingPathComponent("main.bmp"),
                extracted.appendingPathComponent("Main.bmp"),
                extracted.appendingPathComponent("MAIN.BMP")
            ]
            
            // Also check in subdirectories
            if let contents = try? FileManager.default.contentsOfDirectory(at: extracted, includingPropertiesForKeys: nil) {
                for item in contents where item.hasDirectoryPath {
                    mainBmpPaths.append(item.appendingPathComponent("main.bmp"))
                    mainBmpPaths.append(item.appendingPathComponent("Main.bmp"))
                }
            }
            
            for path in mainBmpPaths {
                if let image = NSImage(contentsOf: path) {
                    skinImageView.image = image
                    
                    // Resize window to match skin
                    var frame = self.frame
                    frame.size = image.size
                    setFrame(frame, display: true)
                    
                    print("✅ Loaded skin successfully")
                    break
                }
            }
        }
    }
    
    private func extractSkin(from url: URL) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("WinampLite_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            task.arguments = ["-q", url.path, "-d", tempDir.path]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                return tempDir
            }
        } catch {
            print("Failed to extract skin: \(error)")
        }
        
        return nil
    }
}

// MARK: - Controls View

class ControlsView: NSView {
    private var playButton: NSButton!
    private var stopButton: NSButton!
    private var volumeSlider: NSSlider!
    private var timeLabel: NSTextField!
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupControls()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupControls() {
        // Play button
        playButton = NSButton(frame: NSRect(x: 39, y: 28, width: 23, height: 18))
        playButton.isBordered = false
        playButton.title = ""
        playButton.target = self
        playButton.action = #selector(playPressed)
        addSubview(playButton)
        
        // Stop button
        stopButton = NSButton(frame: NSRect(x: 85, y: 28, width: 23, height: 18))
        stopButton.isBordered = false
        stopButton.title = ""
        stopButton.target = self
        stopButton.action = #selector(stopPressed)
        addSubview(stopButton)
        
        // Volume slider (simplified)
        volumeSlider = NSSlider(frame: NSRect(x: 107, y: 57, width: 68, height: 14))
        volumeSlider.minValue = 0
        volumeSlider.maxValue = 100
        volumeSlider.doubleValue = 50
        volumeSlider.target = self
        volumeSlider.action = #selector(volumeChanged)
        addSubview(volumeSlider)
        
        // Time display
        timeLabel = NSTextField(frame: NSRect(x: 48, y: 72, width: 59, height: 13))
        timeLabel.isBordered = false
        timeLabel.isEditable = false
        timeLabel.backgroundColor = .clear
        timeLabel.textColor = .green
        timeLabel.font = NSFont(name: "Courier", size: 11)
        timeLabel.stringValue = "00:00"
        timeLabel.alignment = .center
        addSubview(timeLabel)
    }
    
    @objc func playPressed() {
        AudioPlayer.shared.togglePlayPause()
    }
    
    @objc func stopPressed() {
        AudioPlayer.shared.stop()
        timeLabel.stringValue = "00:00"
    }
    
    @objc func volumeChanged() {
        AudioPlayer.shared.setVolume(Float(volumeSlider.doubleValue / 100))
    }
}

// MARK: - Simple Audio Player

class AudioPlayer: NSObject {
    static let shared = AudioPlayer()
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    func play(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
            
            // Start timer for time display
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                self.updateTime()
            }
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    func togglePlayPause() {
        if let player = player {
            if player.isPlaying {
                player.pause()
            } else {
                player.play()
            }
        }
    }
    
    func stop() {
        player?.stop()
        player?.currentTime = 0
        timer?.invalidate()
    }
    
    func setVolume(_ volume: Float) {
        player?.volume = volume
    }
    
    private func updateTime() {
        if let player = player {
            let current = Int(player.currentTime)
            let minutes = current / 60
            let seconds = current % 60
            
            // Update time display if we can find it
            if let window = NSApp.mainWindow,
               let controlsView = window.contentView?.subviews.first(where: { $0 is ControlsView }) as? ControlsView,
               let timeLabel = controlsView.subviews.first(where: { $0 is NSTextField }) as? NSTextField {
                timeLabel.stringValue = String(format: "%02d:%02d", minutes, seconds)
            }
        }
    }
}

// MARK: - Main Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()