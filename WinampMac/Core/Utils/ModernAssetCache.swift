//
//  ModernAssetCache.swift
//  WinampMac
//
//  Modern asset caching system using NSCache for proper memory management
//  Replaces unsafe dictionary caching with memory-aware solutions
//  Compatible with macOS 15.0+ and future-proofed for macOS 26.x
//

import Foundation
import AppKit
import OSLog
import Combine

/// Modern asset cache using NSCache with memory pressure awareness
@available(macOS 15.0, *)
public final class ModernAssetCache: ObservableObject {
    
    // MARK: - Logger
    private static let logger = Logger(subsystem: "com.winamp.mac.core", category: "AssetCache")
    
    // MARK: - Cache Instances
    private let imageCache = NSCache<NSString, NSImage>()
    private let dataCache = NSCache<NSString, NSData>()
    private let objectCache = NSCache<NSString, AnyObject>()
    
    // MARK: - Cache Statistics
    @Published public private(set) var statistics = CacheStatistics()
    
    public struct CacheStatistics {
        public var imageHits: Int = 0
        public var imageMisses: Int = 0
        public var dataHits: Int = 0
        public var dataMisses: Int = 0
        public var objectHits: Int = 0
        public var objectMisses: Int = 0
        public var memoryPressureEvents: Int = 0
        public var totalEvictions: Int = 0
        
        public var imageHitRate: Double {
            let total = imageHits + imageMisses
            return total > 0 ? Double(imageHits) / Double(total) : 0.0
        }
        
        public var dataHitRate: Double {
            let total = dataHits + dataMisses
            return total > 0 ? Double(dataHits) / Double(total) : 0.0
        }
        
        public var objectHitRate: Double {
            let total = objectHits + objectMisses
            return total > 0 ? Double(objectHits) / Double(total) : 0.0
        }
    }
    
    // MARK: - Configuration
    private let configuration: CacheConfiguration
    
    public struct CacheConfiguration: Sendable {
        public let maxMemoryUsage: Int
        public let maxItemCount: Int
        public let evictionPolicy: EvictionPolicy
        public let memoryPressureThreshold: Double
        public let enableStatistics: Bool
        public let autoCleanupInterval: TimeInterval
        
        public enum EvictionPolicy: Sendable {
            case lru  // Least Recently Used
            case lfu  // Least Frequently Used
            case fifo // First In, First Out
            case adaptive // Adaptive based on memory pressure
        }
        
        public static let `default` = CacheConfiguration(
            maxMemoryUsage: 200 * 1024 * 1024, // 200MB
            maxItemCount: 1000,
            evictionPolicy: .adaptive,
            memoryPressureThreshold: 0.8,
            enableStatistics: true,
            autoCleanupInterval: 300.0 // 5 minutes
        )
        
        public static let lowMemory = CacheConfiguration(
            maxMemoryUsage: 50 * 1024 * 1024, // 50MB
            maxItemCount: 250,
            evictionPolicy: .lru,
            memoryPressureThreshold: 0.6,
            enableStatistics: true,
            autoCleanupInterval: 180.0 // 3 minutes
        )
        
        public static let highPerformance = CacheConfiguration(
            maxMemoryUsage: 500 * 1024 * 1024, // 500MB
            maxItemCount: 2500,
            evictionPolicy: .lfu,
            memoryPressureThreshold: 0.9,
            enableStatistics: true,
            autoCleanupInterval: 600.0 // 10 minutes
        )
    }
    
    // MARK: - Cache Delegate
    private var cacheDelegate: CacheDelegate?
    
    // MARK: - Memory Monitoring
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var cleanupTimer: Timer?
    private let cacheQueue = DispatchQueue(label: "com.winamp.cache", qos: .utility)
    
    // MARK: - Access Tracking for LFU
    private var accessCounts: [String: Int] = [:]
    private var accessQueue = DispatchQueue(label: "com.winamp.cache.access", qos: .utility)
    
    public init(configuration: CacheConfiguration = .default) {
        self.configuration = configuration
        setupCaches()
        setupMemoryMonitoring()
        setupCleanupTimer()
        setupNotificationObservers()
    }
    
    deinit {
        cleanupTimer?.invalidate()
        memoryPressureSource?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupCaches() {
        // Configure image cache
        imageCache.totalCostLimit = configuration.maxMemoryUsage / 2
        imageCache.countLimit = configuration.maxItemCount / 2
        imageCache.name = "WinampImageCache"
        
        // Configure data cache
        dataCache.totalCostLimit = configuration.maxMemoryUsage / 4
        dataCache.countLimit = configuration.maxItemCount / 4
        dataCache.name = "WinampDataCache"
        
        // Configure object cache
        objectCache.totalCostLimit = configuration.maxMemoryUsage / 4
        objectCache.countLimit = configuration.maxItemCount / 4
        objectCache.name = "WinampObjectCache"
        
        // Set up cache delegates
        cacheDelegate = CacheDelegate(cache: self)
        imageCache.delegate = cacheDelegate
        dataCache.delegate = cacheDelegate
        objectCache.delegate = cacheDelegate
    }
    
    private func setupMemoryMonitoring() {
        // Set up memory pressure monitoring
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: cacheQueue
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        
        memoryPressureSource?.resume()
    }
    
    private func setupCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: configuration.autoCleanupInterval, repeats: true) { [weak self] _ in
            self?.performPeriodicCleanup()
        }
    }
    
    private func setupNotificationObservers() {
        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applicationDidBecomeActive()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applicationDidResignActive()
        }
        
        // Memory warning notifications
        NotificationCenter.default.addObserver(
            forName: NSApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    // MARK: - Image Caching
    public func cacheImage(_ image: NSImage, forKey key: String) {
        let nsKey = key as NSString
        let cost = estimateImageMemoryUsage(image)
        
        cacheQueue.async { [weak self] in
            self?.imageCache.setObject(image, forKey: nsKey, cost: cost)
            self?.updateAccessCount(for: key)
            
            if self?.configuration.enableStatistics == true {
                DispatchQueue.main.async {
                    // Statistics updated when accessed
                }
            }
        }
    }
    
    public func image(forKey key: String) -> NSImage? {
        let nsKey = key as NSString
        let image = imageCache.object(forKey: nsKey)
        
        cacheQueue.async { [weak self] in
            self?.updateAccessCount(for: key)
        }
        
        DispatchQueue.main.async { [weak self] in
            if self?.configuration.enableStatistics == true {
                if image != nil {
                    self?.statistics.imageHits += 1
                } else {
                    self?.statistics.imageMisses += 1
                }
            }
        }
        
        return image
    }
    
    // MARK: - Data Caching
    public func cacheData(_ data: Data, forKey key: String) {
        let nsKey = key as NSString
        let nsData = data as NSData
        let cost = data.count
        
        cacheQueue.async { [weak self] in
            self?.dataCache.setObject(nsData, forKey: nsKey, cost: cost)
            self?.updateAccessCount(for: key)
        }
    }
    
    public func data(forKey key: String) -> Data? {
        let nsKey = key as NSString
        let nsData = dataCache.object(forKey: nsKey)
        
        cacheQueue.async { [weak self] in
            self?.updateAccessCount(for: key)
        }
        
        DispatchQueue.main.async { [weak self] in
            if self?.configuration.enableStatistics == true {
                if nsData != nil {
                    self?.statistics.dataHits += 1
                } else {
                    self?.statistics.dataMisses += 1
                }
            }
        }
        
        return nsData as Data?
    }
    
    // MARK: - Object Caching
    public func cacheObject<T: AnyObject>(_ object: T, forKey key: String, estimatedSize: Int = 1024) {
        let nsKey = key as NSString
        
        cacheQueue.async { [weak self] in
            self?.objectCache.setObject(object, forKey: nsKey, cost: estimatedSize)
            self?.updateAccessCount(for: key)
        }
    }
    
    public func object<T: AnyObject>(forKey key: String, as type: T.Type) -> T? {
        let nsKey = key as NSString
        let object = objectCache.object(forKey: nsKey) as? T
        
        cacheQueue.async { [weak self] in
            self?.updateAccessCount(for: key)
        }
        
        DispatchQueue.main.async { [weak self] in
            if self?.configuration.enableStatistics == true {
                if object != nil {
                    self?.statistics.objectHits += 1
                } else {
                    self?.statistics.objectMisses += 1
                }
            }
        }
        
        return object
    }
    
    // MARK: - Cache Management
    public func removeObject(forKey key: String) {
        let nsKey = key as NSString
        
        cacheQueue.async { [weak self] in
            self?.imageCache.removeObject(forKey: nsKey)
            self?.dataCache.removeObject(forKey: nsKey)
            self?.objectCache.removeObject(forKey: nsKey)
            self?.accessCounts.removeValue(forKey: key)
        }
    }
    
    public func removeAllObjects() {
        cacheQueue.async { [weak self] in
            self?.imageCache.removeAllObjects()
            self?.dataCache.removeAllObjects()
            self?.objectCache.removeAllObjects()
            self?.accessCounts.removeAll()
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.statistics = CacheStatistics()
        }
    }
    
    public func trimToSize(_ targetSize: Int) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Reduce cache limits temporarily
            let oldImageLimit = self.imageCache.totalCostLimit
            let oldDataLimit = self.dataCache.totalCostLimit
            let oldObjectLimit = self.objectCache.totalCostLimit
            
            self.imageCache.totalCostLimit = targetSize / 2
            self.dataCache.totalCostLimit = targetSize / 4
            self.objectCache.totalCostLimit = targetSize / 4
            
            // Force eviction by setting limits back after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.imageCache.totalCostLimit = oldImageLimit
                self.dataCache.totalCostLimit = oldDataLimit
                self.objectCache.totalCostLimit = oldObjectLimit
            }
        }
    }
    
    // MARK: - Memory Pressure Handling
    private func handleMemoryPressure() {
        Self.logger.warning("Memory pressure detected - performing aggressive cleanup")
        
        DispatchQueue.main.async { [weak self] in
            self?.statistics.memoryPressureEvents += 1
        }
        
        switch configuration.evictionPolicy {
        case .lru:
            // NSCache handles LRU automatically
            trimToSize(configuration.maxMemoryUsage / 2)
            
        case .lfu:
            performLFUEviction()
            
        case .fifo:
            performFIFOEviction()
            
        case .adaptive:
            performAdaptiveEviction()
        }
    }
    
    private func handleMemoryWarning() {
        Self.logger.info("Received memory warning - clearing caches")
        removeAllObjects()
    }
    
    private func performLFUEviction() {
        accessQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Sort by access count and remove least frequently used
            let sortedAccess = self.accessCounts.sorted { $0.value < $1.value }
            let keysToRemove = Array(sortedAccess.prefix(sortedAccess.count / 2).map { $0.key })
            
            for key in keysToRemove {
                self.removeObject(forKey: key)
            }
        }
    }
    
    private func performFIFOEviction() {
        // For FIFO, we'd need to track insertion order
        // For now, fall back to standard NSCache eviction
        trimToSize(configuration.maxMemoryUsage / 2)
    }
    
    private func performAdaptiveEviction() {
        // Adaptive policy considers memory pressure level
        let memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = memoryInfo.resident_size
            let availableMemory = ProcessInfo.processInfo.physicalMemory
            let memoryRatio = Double(usedMemory) / Double(availableMemory)
            
            if memoryRatio > configuration.memoryPressureThreshold {
                // Aggressive cleanup
                trimToSize(configuration.maxMemoryUsage / 4)
            } else {
                // Conservative cleanup
                trimToSize(Int(Double(configuration.maxMemoryUsage) * 0.8))
            }
        } else {
            // Fall back to standard cleanup
            trimToSize(configuration.maxMemoryUsage / 2)
        }
    }
    
    // MARK: - Periodic Maintenance
    private func performPeriodicCleanup() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Clean up unused access count entries
            // This prevents the access counts dictionary from growing indefinitely
            let currentKeys = Set([
                self.imageCache.name,
                self.dataCache.name,
                self.objectCache.name
            ].compactMap { $0 })
            
            // Remove access counts for keys no longer in cache
            // This is a simplified approach - in practice you'd need to track actual keys
            if self.accessCounts.count > self.configuration.maxItemCount * 2 {
                self.accessCounts.removeAll()
            }
        }
    }
    
    private func applicationDidBecomeActive() {
        // Potentially pre-load commonly used assets
        Self.logger.debug("Application became active - cache ready")
    }
    
    private func applicationDidResignActive() {
        // Perform cleanup when app goes to background
        performPeriodicCleanup()
    }
    
    // MARK: - Utilities
    private func estimateImageMemoryUsage(_ image: NSImage) -> Int {
        let size = image.size
        let scale = image.recommendedLayerContentsScale(0.0)
        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        
        // Estimate 4 bytes per pixel (RGBA)
        return Int(pixelWidth * pixelHeight * 4)
    }
    
    private func updateAccessCount(for key: String) {
        accessQueue.async { [weak self] in
            self?.accessCounts[key, default: 0] += 1
        }
    }
    
    // MARK: - Cache Information
    public func getCacheInfo() -> CacheInfo {
        return CacheInfo(
            imageCount: imageCache.countLimit,
            dataCount: dataCache.countLimit,
            objectCount: objectCache.countLimit,
            totalMemoryLimit: configuration.maxMemoryUsage,
            currentMemoryUsage: estimateCurrentMemoryUsage(),
            statistics: statistics
        )
    }
    
    public struct CacheInfo {
        public let imageCount: Int
        public let dataCount: Int
        public let objectCount: Int
        public let totalMemoryLimit: Int
        public let currentMemoryUsage: Int
        public let statistics: CacheStatistics
        
        public var memoryUsagePercentage: Double {
            return totalMemoryLimit > 0 ? Double(currentMemoryUsage) / Double(totalMemoryLimit) : 0.0
        }
    }
    
    private func estimateCurrentMemoryUsage() -> Int {
        // This is an approximation - NSCache doesn't provide exact current usage
        let imageEstimate = imageCache.totalCostLimit / 4  // Assume 25% full
        let dataEstimate = dataCache.totalCostLimit / 4
        let objectEstimate = objectCache.totalCostLimit / 4
        
        return imageEstimate + dataEstimate + objectEstimate
    }
}

// MARK: - Cache Delegate
@available(macOS 15.0, *)
private class CacheDelegate: NSObject, NSCacheDelegate {
    weak var cache: ModernAssetCache?
    
    init(cache: ModernAssetCache) {
        self.cache = cache
        super.init()
    }
    
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: AnyObject) {
        DispatchQueue.main.async { [weak self] in
            self?.cache?.statistics.totalEvictions += 1
        }
    }
}

// MARK: - Convenience Extensions
@available(macOS 15.0, *)
public extension ModernAssetCache {
    
    /// Cache a skin asset with automatic key generation
    func cacheSkinAsset(_ image: NSImage, skinName: String, assetType: String) {
        let key = "\(skinName)_\(assetType)"
        cacheImage(image, forKey: key)
    }
    
    /// Retrieve a skin asset with automatic key generation
    func skinAsset(skinName: String, assetType: String) -> NSImage? {
        let key = "\(skinName)_\(assetType)"
        return image(forKey: key)
    }
    
    /// Batch cache multiple images
    func batchCacheImages(_ images: [String: NSImage]) {
        for (key, image) in images {
            cacheImage(image, forKey: key)
        }
    }
    
    /// Preload commonly used assets
    func preloadCommonAssets() {
        // This would load default skin assets, common UI elements, etc.
        Self.logger.info("Preloading common assets")
    }
}