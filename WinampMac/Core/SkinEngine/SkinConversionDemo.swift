//
//  SkinConversionDemo.swift
//  WinampMac
//
//  Integration prototype demonstrating end-to-end .wsz to macOS skin conversion
//  Shows real Winamp skin running on macOS with proper coordinate mapping and rendering
//

import Foundation
import AppKit
import SwiftUI
import Metal
import MetalKit
import OSLog

/// Demonstration view controller that shows a converted Winamp skin in action
@available(macOS 15.0, *)
public final class SkinConversionDemo: NSViewController, ObservableObject {
    
    // MARK: - Logger
    private static let logger = Logger(subsystem: "com.winamp.mac.demo", category: "SkinDemo")
    
    // MARK: - UI Components
    private var metalView: MTKView!
    private var renderer: WinampSkinRenderer!
    private var skinConverter: WinampSkinConverter!
    
    // MARK: - State
    @Published public private(set) var currentSkin: MacOSSkin?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var loadingProgress: Double = 0.0
    @Published public private(set) var statusMessage: String = "Ready to load skin"
    
    // MARK: - Demo Configuration
    private let demoSkinPaths: [String] = [
        "Carrie-Anne Moss.wsz",
        "Deus_Ex_Amp_by_AJ.wsz",
        "Purple_Glow.wsz",
        "netscape_winamp.wsz"
    ]
    
    // MARK: - Lifecycle
    
    public override func loadView() {
        setupView()
        setupMetalView()
        setupConverter()
        setupRenderer()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupDemoUI()
        
        // Automatically load first demo skin
        Task {
            await loadFirstDemoSkin()
        }
    }
    
    // MARK: - Setup
    
    private func setupView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
    }
    
    private func setupMetalView() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        metalView = MTKView(frame: NSRect(x: 50, y: 200, width: 275, height: 116))
        metalView.device = device
        metalView.preferredFramesPerSecond = 60
        metalView.enableSetNeedsDisplay = true
        metalView.isPaused = false
        metalView.colorPixelFormat = .bgra8Unorm
        
        view.addSubview(metalView)
    }
    
    private func setupConverter() {
        skinConverter = WinampSkinConverter()
        
        // Observe conversion progress
        skinConverter.$conversionProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.loadingProgress = progress
            }
            .store(in: &cancellables)
        
        skinConverter.$currentOperation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] operation in
                self?.statusMessage = operation
            }
            .store(in: &cancellables)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    private func setupRenderer() {
        renderer = WinampSkinRenderer(metalView: metalView)
        metalView.delegate = renderer
    }
    
    private func setupDemoUI() {
        // Create demo controls
        let controlsView = NSView(frame: NSRect(x: 400, y: 200, width: 350, height: 300))
        view.addSubview(controlsView)
        
        // Title label
        let titleLabel = NSTextField(labelWithString: "Winamp Skin Conversion Demo")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.frame = NSRect(x: 0, y: 260, width: 350, height: 30)
        titleLabel.alignment = .center
        controlsView.addSubview(titleLabel)
        
        // Status label
        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: 0, y: 220, width: 350, height: 20)
        statusLabel.alignment = .center
        statusLabel.bind(.value, to: self, withKeyPath: "statusMessage", options: nil)
        controlsView.addSubview(statusLabel)
        
        // Progress indicator
        let progressIndicator = NSProgressIndicator(frame: NSRect(x: 50, y: 190, width: 250, height: 20))
        progressIndicator.style = .bar
        progressIndicator.bind(.value, to: self, withKeyPath: "loadingProgress", options: nil)
        controlsView.addSubview(progressIndicator)
        
        // Skin selection buttons
        for (index, skinName) in demoSkinPaths.enumerated() {
            let button = NSButton(frame: NSRect(x: 50, y: 150 - (index * 30), width: 250, height: 25))
            button.title = skinName.replacingOccurrences(of: ".wsz", with: "")
            button.bezelStyle = .rounded
            button.target = self
            button.action = #selector(loadSkinButtonClicked(_:))
            button.tag = index
            controlsView.addSubview(button)
        }
        
        // Info panel
        let infoPanel = NSView(frame: NSRect(x: 50, y: 50, width: 700, height: 120))
        infoPanel.wantsLayer = true
        infoPanel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        infoPanel.layer?.cornerRadius = 8
        view.addSubview(infoPanel)
        
        let infoText = """
        This demo shows real-time conversion of Windows Winamp skins (.wsz files) to macOS format.
        
        Features demonstrated:
        • Windows RGB → macOS sRGB color space conversion
        • Windows coordinate system → macOS coordinate system (Y-axis flip)
        • Bitmap extraction and Metal texture atlas generation
        • Region parsing for hit-test areas and window shapes
        • Real-time rendering with Metal performance shaders
        """
        
        let infoLabel = NSTextField(wrappingLabelWithString: infoText)
        infoLabel.frame = NSRect(x: 20, y: 20, width: 660, height: 80)
        infoLabel.font = NSFont.systemFont(ofSize: 12)
        infoPanel.addSubview(infoLabel)
    }
    
    // MARK: - Demo Actions
    
    @objc private func loadSkinButtonClicked(_ sender: NSButton) {
        let skinIndex = sender.tag
        guard skinIndex < demoSkinPaths.count else { return }
        
        let skinName = demoSkinPaths[skinIndex]
        Task {
            await loadDemoSkin(named: skinName)
        }
    }
    
    private func loadFirstDemoSkin() async {
        guard !demoSkinPaths.isEmpty else { return }
        await loadDemoSkin(named: demoSkinPaths[0])
    }
    
    private func loadDemoSkin(named skinName: String) async {
        await MainActor.run {
            isLoading = true
            statusMessage = "Loading \(skinName)..."
        }
        
        do {
            // Find the skin file
            let currentDirectory = FileManager.default.currentDirectoryPath
            let skinURL = URL(fileURLWithPath: currentDirectory).appendingPathComponent(skinName)
            
            guard FileManager.default.fileExists(atPath: skinURL.path) else {
                await MainActor.run {
                    statusMessage = "Skin file not found: \(skinName)"
                    isLoading = false
                }
                return
            }
            
            // Convert the skin
            let convertedSkin = try await skinConverter.convertSkin(from: skinURL)
            
            await MainActor.run {
                currentSkin = convertedSkin
                statusMessage = "Successfully loaded: \(convertedSkin.name)"
                isLoading = false
                
                // Update renderer with new skin
                renderer.setSkin(convertedSkin)
            }
            
            Self.logger.info("Demo: Successfully loaded skin \(convertedSkin.name)")
            
        } catch {
            await MainActor.run {
                statusMessage = "Failed to load skin: \(error.localizedDescription)"
                isLoading = false
            }
            
            Self.logger.error("Demo: Failed to load skin \(skinName): \(error)")
        }
    }
    
    // MARK: - Skin Analysis
    
    /// Display detailed analysis of the converted skin
    private func showSkinAnalysis(_ skin: MacOSSkin) {
        let analysisWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        analysisWindow.title = "Skin Analysis: \(skin.name)"
        analysisWindow.center()
        
        let analysisView = SkinAnalysisView(skin: skin)
        analysisWindow.contentView = NSHostingView(rootView: analysisView)
        analysisWindow.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Metal Renderer

/// Metal renderer for displaying converted Winamp skins
@available(macOS 15.0, *)
@MainActor
private final class WinampSkinRenderer: NSObject, MTKViewDelegate {
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var currentSkin: MacOSSkin?
    
    // Rendering state
    private var renderPipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    
    init(metalView: MTKView) {
        self.device = metalView.device!
        self.commandQueue = device.makeCommandQueue()!
        
        super.init()
        setupRenderPipeline()
        setupVertexBuffer()
    }
    
    func setSkin(_ skin: MacOSSkin) {
        currentSkin = skin
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes
    }
    
    func draw(in view: MTKView) {
        guard let currentSkin = currentSkin,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            return
        }
        
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let pipelineState = renderPipelineState else {
            commandBuffer.commit()
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Render main skin texture
        if let mainAtlas = currentSkin.textureAtlases.first(where: { $0.name == "main" }) {
            renderEncoder.setFragmentTexture(mainAtlas.texture, index: 0)
            
            if let vertexBuffer = vertexBuffer {
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // MARK: - Setup
    
    private func setupRenderPipeline() {
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "skinVertexShader")
        let fragmentFunction = library?.makeFunction(name: "skinFragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
        }
    }
    
    private func setupVertexBuffer() {
        // Create a full-screen quad for rendering the skin
        let vertices: [Float] = [
            -1.0, -1.0, 0.0, 1.0,  // Bottom-left
             1.0, -1.0, 1.0, 1.0,  // Bottom-right
            -1.0,  1.0, 0.0, 0.0,  // Top-left
             1.0,  1.0, 1.0, 0.0   // Top-right
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
    }
}

// MARK: - SwiftUI Analysis View

@available(macOS 15.0, *)
private struct SkinAnalysisView: View {
    let skin: MacOSSkin
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Skin Analysis: \(skin.name)")
                .font(.title2)
                .bold()
            
            Group {
                HStack {
                    Text("Original Format:")
                    Spacer()
                    Text("Windows .wsz")
                }
                
                HStack {
                    Text("Converted Images:")
                    Spacer()
                    Text("\(skin.convertedImages.count)")
                }
                
                HStack {
                    Text("Texture Atlases:")
                    Spacer()
                    Text("\(skin.textureAtlases.count)")
                }
                
                HStack {
                    Text("Hit-test Regions:")
                    Spacer()
                    Text("\(skin.hitTestRegions.count)")
                }
                
                HStack {
                    Text("Visualization Colors:")
                    Spacer()
                    Text("\(skin.visualizationColors.count)")
                }
            }
            
            Divider()
            
            Text("Texture Atlases:")
                .font(.headline)
            
            ForEach(skin.textureAtlases.indices, id: \.self) { index in
                let atlas = skin.textureAtlases[index]
                HStack {
                    Text("• \(atlas.name)")
                    Spacer()
                    Text("\(Int(atlas.size.width))×\(Int(atlas.size.height))")
                    Text("(\(atlas.uvMappings.count) textures)")
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Combine Import
import Combine