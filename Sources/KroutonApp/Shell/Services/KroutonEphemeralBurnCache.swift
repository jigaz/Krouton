import Combine
import Darwin.Mach
import Foundation

//
//  KroutonEphemeralBurnCache.swift
//  Krouton — Optical Media Mastering Package (Optical Media Mastering Workspace)
//
//  1. Ephemeral Mach VM Burn Ring-Buffer (`vm_allocate` / `vm_deallocate`):
//     Grabs physical RAM ONLY while a disc burn/mux is actively running and
//     immediately returns 100% of pages to the macOS kernel upon completion.
//  2. Zero-Idle CPU Power Governor (`KroutonIdlePowerMonitor`):
//     Tracks NSApplication active state, window occlusion, and kernel memory
//     pressure so Krouton idles at ~0.0% CPU when not actively mastering.
//

// MARK: - Ephemeral Kernel Page-Aligned Burn Cache (Zero Idle RAM Overhead)
public final class KroutonEphemeralBurnCache: @unchecked Sendable {
    public static let shared = KroutonEphemeralBurnCache()

    private let lock = NSLock()
    private var vmAddress: vm_address_t = 0
    private var allocatedBytes: vm_size_t = 0
    private var isAcquired: Bool = false

    private init() {}

    /// Current RAM bytes held by the burn ring-buffer (0 bytes whenever idle!)
    public var activeBufferBytes: Int {
        lock.lock()
        defer { lock.unlock() }
        return isAcquired ? Int(allocatedBytes) : 0
    }

    /// Grabs a page-aligned RAM cache from the Mach kernel ONLY when a disc burn begins.
    /// Defaults to a 32 MiB optical underrun protection buffer aligned to 16 KB Apple Silicon pages.
    @discardableResult
    public func acquireForActiveBurn(megabytes: Int = 32) -> UnsafeMutableRawPointer? {
        lock.lock()
        defer { lock.unlock() }

        if isAcquired, vmAddress != 0 {
            return UnsafeMutableRawPointer(bitPattern: UInt(vmAddress))
        }

        let requestedBytes = vm_size_t(max(4, megabytes) * 1024 * 1024)
        var addr: vm_address_t = 0
        let kr = vm_allocate(mach_task_self_, &addr, requestedBytes, VM_FLAGS_ANYWHERE)
        guard kr == KERN_SUCCESS, addr != 0 else {
            return nil
        }

        // Hint sequential read/write to Apple Silicon hardware prefetcher
        if let ptr = UnsafeMutableRawPointer(bitPattern: UInt(addr)) {
            madvise(ptr, Int(requestedBytes), MADV_SEQUENTIAL)
        }

        self.vmAddress = addr
        self.allocatedBytes = requestedBytes
        self.isAcquired = true
        return UnsafeMutableRawPointer(bitPattern: UInt(addr))
    }

    /// Immediately releases 100% of the burn buffer pages back to the macOS kernel (`vm_deallocate`)
    /// and purges URLCache / autorelease pools so physical RAM drops immediately after a burn.
    public func releaseImmediatelyAfterBurn() {
        lock.lock()
        let addr = self.vmAddress
        let size = self.allocatedBytes
        let wasAcquired = self.isAcquired
        self.vmAddress = 0
        self.allocatedBytes = 0
        self.isAcquired = false
        lock.unlock()

        if wasAcquired, addr != 0, size > 0 {
            if let ptr = UnsafeMutableRawPointer(bitPattern: UInt(addr)) {
                // Mark pages free before kernel unmapping
                madvise(ptr, Int(size), MADV_FREE)
            }
            vm_deallocate(mach_task_self_, addr, size)
        }

        // Purge transient Foundation caches & notify LUT/formatter caches to compact
        URLCache.shared.removeAllCachedResponses()
        NotificationCenter.default.post(name: .kroutonDidReleaseEphemeralRAM, object: nil)
    }

    deinit {
        releaseImmediatelyAfterBurn()
    }
}

public extension Notification.Name {
    static let kroutonDidReleaseEphemeralRAM = Notification.Name("krouton.didReleaseEphemeralRAM")
}

// MARK: - Zero-Idle CPU Power & App-Nap Governor
@MainActor
public final class KroutonIdlePowerMonitor: ObservableObject {
    public static let shared = KroutonIdlePowerMonitor()

    /// True ONLY when the Krouton app is foregrounded AND at least one window is visible on screen.
    /// Views & scopes bind to this to pause TimelineViews and animations at 0.0% CPU when backgrounded.
    @Published public private(set) var isAppVisiblyActive: Bool = true

    /// True when a hardware burn, rip, or verification task requires sustained background execution.
    @Published public private(set) var isPerformingHardwareIO: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var ioActivityToken: NSObjectProtocol?

    private init() {
        setupLifecycleObservers()
        setupKernelMemoryPressureHandler()
    }

    private func setupLifecycleObservers() {
        let nc = NotificationCenter.default

        nc.publisher(for: KroutonOSDesktopBridge.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isAppVisiblyActive = true
            }
            .store(in: &cancellables)

        nc.publisher(for: KroutonOSDesktopBridge.didResignActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.isAppVisiblyActive = false
                // If no burn is running when the user switches away, release any transient caches immediately
                if !self.isPerformingHardwareIO {
                    KroutonEphemeralBurnCache.shared.releaseImmediatelyAfterBurn()
                }
            }
            .store(in: &cancellables)

        nc.publisher(for: KroutonOSDesktopBridge.didChangeWindowOcclusionNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.isAppVisiblyActive = KroutonOSDesktopBridge.isApplicationVisiblyActive()
            }
            .store(in: &cancellables)
    }

    private func setupKernelMemoryPressureHandler() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self, !self.isPerformingHardwareIO else { return }
                KroutonEphemeralBurnCache.shared.releaseImmediatelyAfterBurn()
            }
        }
        source.resume()
        self.memoryPressureSource = source
    }
}
