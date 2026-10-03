//
//  NEObservablleManager.swift
//  SwByeDPI
//
//  Created by developer on 06.03.2026.
//

import SwiftUI
import CoreFoundation
import NetworkExtension

struct PalkaTunnelLogEntry: Codable, Equatable, Identifiable {
    let timestamp: TimeInterval
    let level: String
    let message: String

    var id: String {
        "\(timestamp)-\(level)-\(message)"
    }
}

struct PalkaTunnelRuntimeStats: Codable, Equatable {
    let coreRunning: Bool
    let socksAddress: String
    let socksPort: Int
    let uptimeSeconds: Int
    let upPackets: Int
    let upBytes: Int
    let downPackets: Int
    let downBytes: Int
    let logs: [PalkaTunnelLogEntry]

    var totalPackets: Int { upPackets + downPackets }
}

fileprivate func handleByeDPIVpnStart(notificationCenter: CFNotificationCenter?, observer: UnsafeMutableRawPointer?, notificationName: CFNotificationName?, object: UnsafeRawPointer?, info: CFDictionary?) {
    //UserDefaultsAppProperties.appGroupUserDefaults.set(true, forKey: UserDefaultsAppKeys.byeDPIVPNRunning.rawValue)
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: .BBDVpnStarted, object: nil)
    }
}

fileprivate func handleByeDPIVpnStop(notificationCenter: CFNotificationCenter?, observer: UnsafeMutableRawPointer?, notificationName: CFNotificationName?, object: UnsafeRawPointer?, info: CFDictionary?) {
    //UserDefaultsAppProperties.appGroupUserDefaults.set(false, forKey: UserDefaultsAppKeys.byeDPIVPNRunning.rawValue)
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: .BBDVpnStopped, object: nil)
    }
}

@available(tvOS 17.0, *)
class NEObservableManager: ObservableObject {
    
    @Published fileprivate(set) var neTunnelProviderManager: NETunnelProviderManager?
    @Published fileprivate(set) var vpnRunning: Bool
    @Published fileprivate(set) var tunnelStats: PalkaTunnelRuntimeStats?
    @Published fileprivate(set) var runtimeLogs: [PalkaTunnelLogEntry]
    
    fileprivate let _cfNotificationCenter: CFNotificationCenter
    fileprivate var _startVpnObserver: UnsafeRawPointer?
    fileprivate var _stopVpnObserver: UnsafeRawPointer?
    fileprivate var _vpnStartedNotificationObserver: NSObjectProtocol?
    fileprivate var _vpnStoppedNotificationObserver: NSObjectProtocol?
    fileprivate var _vpnStatusNotificationObserver: NSObjectProtocol?
    fileprivate var _statsTimer: Timer?
    fileprivate var _lastObservedStatus: NEVPNStatus?
    
    init(initCompletion: @escaping (NETunnelProviderManager?, (any Error)?) -> Void) {
        neTunnelProviderManager = nil
        vpnRunning = UserDefaultsAppProperties.byeDPIVPNRunning
        tunnelStats = nil
        runtimeLogs = [PalkaTunnelLogEntry(
            timestamp: Date().timeIntervalSince1970,
            level: "info",
            message: "MuseDPI interface ready"
        )]
        _cfNotificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        _startVpnObserver = nil
        _stopVpnObserver = nil
        _vpnStartedNotificationObserver = nil
        _vpnStoppedNotificationObserver = nil
        _vpnStatusNotificationObserver = nil
        _statsTimer = nil
        _lastObservedStatus = nil
        
        _vpnStartedNotificationObserver = NotificationCenter.default.addObserver(
            forName: .BBDVpnStarted,
            object: nil,
            queue: .main,
            using: handleVpnStart
        )
        _vpnStoppedNotificationObserver = NotificationCenter.default.addObserver(
            forName: .BBDVpnStopped,
            object: nil,
            queue: .main,
            using: handleVpnStop
        )
        _vpnStatusNotificationObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncVpnState()
        }
        
        
        _startVpnObserver = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        _stopVpnObserver = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(_cfNotificationCenter, _startVpnObserver, handleByeDPIVpnStart, CFNotificationName.byeDPIVpnStarted.rawValue, nil, .deliverImmediately)
        CFNotificationCenterAddObserver(_cfNotificationCenter, _stopVpnObserver, handleByeDPIVpnStop, CFNotificationName.byeDPIVpnStopped.rawValue, nil, .deliverImmediately)
        getOrInitNEManager(completion: initCompletion)
        _statsTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshTunnelStats()
        }
        loadPersistedTunnelLogs()
    }
    
    deinit {
        CFNotificationCenterRemoveEveryObserver(_cfNotificationCenter, _startVpnObserver)
        CFNotificationCenterRemoveEveryObserver(_cfNotificationCenter, _stopVpnObserver)
        if let observer = _vpnStartedNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = _vpnStoppedNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = _vpnStatusNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        _statsTimer?.invalidate()
    }
    
    func startConnection(completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        appendRuntimeLog("VPN start requested")
#if DEBUG
        if (ProcessInfo.processInfo.previewMode) {
            //Disable real VPN connection for preview
            vpnRunning = true
            completion(true, nil)
            return
        }
#endif
        if let safeManager = neTunnelProviderManager {
            startConnection(manager: safeManager, completion: completion)
            return
        }
        getOrInitNEManager { manager, err in
            guard let safeManager = manager else {
                completion(false, err)
                return
            }
            self.startConnection(manager: safeManager, completion: completion)
        }
    }
    
    func stopConnection(
        completion: @escaping (_ success: Bool, _ error: Error?) -> Void = { _, _ in }
    ) {
        appendRuntimeLog("VPN stop requested")
#if DEBUG
        if (ProcessInfo.processInfo.previewMode) {
            //Disable real VPN connection for preview
            vpnRunning = false
            completion(true, nil)
            return
        }
#endif
        if let safeManager = neTunnelProviderManager {
            stopConnection(manager: safeManager, completion: completion)
            return
        }
        getOrInitNEManager { manager, err in
            guard let safeManager = manager else {
                completion(false, err)
                return
            }
            self.stopConnection(manager: safeManager, completion: completion)
        }
    }

    fileprivate func stopConnection(
        manager: NETunnelProviderManager,
        completion: @escaping (_ success: Bool, _ error: Error?) -> Void
    ) {
        manager.connection.stopVPNTunnel()
        waitForTunnel(
            manager: manager,
            shouldBeConnected: false,
            deadline: Date().addingTimeInterval(12),
            completion: completion
        )
    }
    
    fileprivate func startConnection(manager: NETunnelProviderManager, completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        manager.loadFromPreferences { loadErr in
            if let safeLoadErr = loadErr {
                self.appendRuntimeLog("Loading VPN preferences failed: \(safeLoadErr.localizedDescription)", level: "error")
                if (self.vpnRunning) {
                    self.vpnRunning = false
                }
                completion(false, safeLoadErr)
                return
            }
            let firstTimeVpnSet = manager.protocolConfiguration == nil
            let startTunnelOptions = NEUtil.generateConnectionParamsFromAppUserDefaults()
            manager.isEnabled = true
            manager.localizedDescription = "MuseDPI"
            let vpnProtocol = NETunnelProviderProtocol()
            vpnProtocol.providerConfiguration = startTunnelOptions
            vpnProtocol.serverAddress = UserDefaultsAppProperties.byeDPIListenIp
            vpnProtocol.providerBundleIdentifier = Constants.VPN_PROVIDER_BUNDLE_ID
            vpnProtocol.includeAllNetworks = false
            if #available(iOS 16.4, *) {
                vpnProtocol.excludeAPNs = true
            }
            if #available(iOS 14.2, *) {
                vpnProtocol.excludeLocalNetworks = true
                vpnProtocol.enforceRoutes = false
            }
            if #available(iOS 17.4, *) {
                vpnProtocol.excludeDeviceCommunication = true
            }
            manager.protocolConfiguration = vpnProtocol
            self.applyOnDemandPreferences(to: manager)
            manager.saveToPreferences { saveErr in
                if let safeSaveErr = saveErr {
                    self.appendRuntimeLog("Saving VPN preferences failed: \(safeSaveErr.localizedDescription)", level: "error")
                    if (self.vpnRunning) {
                        self.vpnRunning = false
                    }
                    completion(false, safeSaveErr)
                    return
                }
                if (firstTimeVpnSet) {
                    //Load after the first save
                    self.startConnection(manager: manager, completion: completion)
                    return
                }
                do {
                    self.appendRuntimeLog("Launching Packet Tunnel extension")
                    try manager.connection.startVPNTunnel(options: startTunnelOptions)
                    self.waitForTunnel(
                        manager: manager,
                        shouldBeConnected: true,
                        deadline: Date().addingTimeInterval(20),
                        completion: completion
                    )
                } catch {
                    self.appendRuntimeLog("Packet Tunnel launch failed: \(error.localizedDescription)", level: "error")
#if DEBUG
                    print("Start VPN error")
                    print(error)
#endif
                    if (self.vpnRunning) {
                        self.vpnRunning = false
                    }
                    completion(false, error)
                }
            }
        }
    }

    func configureOnDemand(
        enabled: Bool,
        includeWiFi: Bool,
        includeCellular: Bool,
        completion: @escaping (Error?) -> Void
    ) {
        UserDefaultsAppProperties.onDemandEnabled = enabled
        UserDefaultsAppProperties.onDemandWiFiEnabled = includeWiFi
        UserDefaultsAppProperties.onDemandCellularEnabled = includeCellular

        getOrInitNEManager { manager, error in
            guard let manager = manager else {
                completion(error)
                return
            }
            manager.loadFromPreferences { loadError in
                guard loadError == nil else {
                    completion(loadError)
                    return
                }
                self.applyOnDemandPreferences(to: manager)
                manager.saveToPreferences(completionHandler: completion)
            }
        }
    }

    private func applyOnDemandPreferences(to manager: NETunnelProviderManager) {
        let enabled = UserDefaultsAppProperties.onDemandEnabled
        var rules: [NEOnDemandRule] = []
        if enabled && UserDefaultsAppProperties.onDemandWiFiEnabled {
            let rule = NEOnDemandRuleConnect()
            rule.interfaceTypeMatch = .wiFi
            rules.append(rule)
        }
        if enabled && UserDefaultsAppProperties.onDemandCellularEnabled {
            let rule = NEOnDemandRuleConnect()
            rule.interfaceTypeMatch = .cellular
            rules.append(rule)
        }
        manager.onDemandRules = rules
        manager.isOnDemandEnabled = enabled && !rules.isEmpty
    }
    
    fileprivate func getOrInitNEManager(completion: @escaping (NETunnelProviderManager?, (any Error)?) -> Void) {
        if let safeManager = neTunnelProviderManager {
            syncVpnState(manager: safeManager)
            completion(safeManager, nil)
            return
        }
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let safeError = error {
                print(safeError)
                completion(nil, error)
                return
            }
            guard let safeManagers = managers else {
                print("NE Tunnel Provider managers array from cache is nil - Init the new one")
                let manager = NETunnelProviderManager()
                self.neTunnelProviderManager = manager
                if (self.vpnRunning) {
                    self.vpnRunning = false
                }
                completion(manager, nil)
                return
            }
            if (safeManagers.isEmpty) {
                print("NE Tunnel Provider managers array from cache is empty -> Init the new one")
                let manager = NETunnelProviderManager()
                self.neTunnelProviderManager = manager
                if (self.vpnRunning) {
                    self.vpnRunning = false
                }
                completion(manager, nil)
                return
            }
            self.neTunnelProviderManager = safeManagers[0]
            self.syncVpnState(manager: safeManagers[0])
            completion(safeManagers[0], nil)
        }
    }
    
    fileprivate func handleVpnStart(_ notification: Notification) {
        syncVpnState()
    }
    
    fileprivate func handleVpnStop(_ notification: Notification) {
        vpnRunning = false
        tunnelStats = nil
        appendRuntimeLog("Packet Tunnel stopped")
    }

    func refreshTunnelStats() {
        loadPersistedTunnelLogs()
        guard vpnRunning,
              let session = neTunnelProviderManager?.connection as? NETunnelProviderSession else {
            if tunnelStats != nil {
                tunnelStats = nil
            }
            return
        }
        do {
            try session.sendProviderMessage(Data("stats".utf8)) { [weak self] data in
                guard let data = data,
                      let stats = try? JSONDecoder().decode(PalkaTunnelRuntimeStats.self, from: data) else {
                    return
                }
                DispatchQueue.main.async {
                    guard let self = self,
                          self.vpnRunning,
                          let currentSession = self.neTunnelProviderManager?.connection as? NETunnelProviderSession,
                          currentSession === session else { return }
                    self.tunnelStats = stats
                    self.mergeRuntimeLogs(stats.logs)
                }
            }
        } catch {
            // The session can transition between the status check and the
            // message. The next timer tick will retry after it settles.
        }
    }

    private func syncVpnState(manager: NETunnelProviderManager? = nil) {
        let update = {
            let activeManager = manager ?? self.neTunnelProviderManager
            let status = activeManager?.connection.status ?? .invalid
            self.vpnRunning = activeManager.map {
                NEObservableManager.isVpnRunning(status: $0.connection.status)
            } ?? false
            if self._lastObservedStatus != status {
                self._lastObservedStatus = status
                self.appendRuntimeLog("VPN status: \(Self.statusLogName(status))")
            }
            if self.vpnRunning {
                self.refreshTunnelStats()
            } else {
                self.tunnelStats = nil
            }
        }
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    private func waitForTunnel(
        manager: NETunnelProviderManager,
        shouldBeConnected: Bool,
        deadline: Date,
        completion: @escaping (_ success: Bool, _ error: Error?) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let status = manager.connection.status
            self.vpnRunning = NEObservableManager.isVpnRunning(status: status)

            let reachedTarget: Bool
            if shouldBeConnected {
                // PacketTunnelProvider reports .connected only after network settings,
                // ByeDPI and tun2socks have all started successfully.
                reachedTarget = status == .connected
            } else {
                reachedTarget = status == .disconnected || status == .invalid
            }

            if reachedTarget {
                if shouldBeConnected {
                    // A new extension instance owns a new set of counters.
                    // Never let automation validate it with data from the
                    // previous tunnel session.
                    self.tunnelStats = nil
                    self.refreshTunnelStats()
                } else {
                    self.tunnelStats = nil
                }
                self.appendRuntimeLog(
                    shouldBeConnected ? "VPN connection is active" : "VPN connection is stopped",
                    level: "success"
                )
                completion(true, nil)
                return
            }

            if Date() >= deadline {
                if shouldBeConnected {
                    manager.connection.stopVPNTunnel()
                }
                let messageKey = shouldBeConnected
                    ? "palkaVPNConnectTimeout"
                    : "palkaVPNDisconnectTimeout"
                self.appendRuntimeLog(
                    "VPN transition timed out at status \(Self.statusLogName(status))",
                    level: "error"
                )
                completion(
                    false,
                    NSError(
                        domain: "MuseDPI.VPN",
                        code: shouldBeConnected ? 1001 : 1002,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "\(palkaLocalized(messageKey)) [NEVPNStatus=\(status.rawValue)]"
                        ]
                    )
                )
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.waitForTunnel(
                    manager: manager,
                    shouldBeConnected: shouldBeConnected,
                    deadline: deadline,
                    completion: completion
                )
            }
        }
    }
    
    fileprivate static func isVpnRunning(status: NEVPNStatus) -> Bool {
        switch (status) {
        case .connected: return true
        case .connecting: return false
        case .disconnecting: return false
        case .disconnected: return false
        case .invalid: return false
        case .reasserting: return false
        @unknown default:
            print("Unknown NEVPNStatus status")
            print(status)
            return false
        }
    }

    func clearRuntimeLogs() {
        runtimeLogs.removeAll()
    }

    private func appendRuntimeLog(_ message: String, level: String = "info") {
        let append = {
            self.mergeRuntimeLogs([PalkaTunnelLogEntry(
                timestamp: Date().timeIntervalSince1970,
                level: level,
                message: message
            )])
        }
        if Thread.isMainThread {
            append()
        } else {
            DispatchQueue.main.async(execute: append)
        }
    }

    private func mergeRuntimeLogs(_ entries: [PalkaTunnelLogEntry]) {
        guard !entries.isEmpty else { return }
        var mergedByID = Dictionary(uniqueKeysWithValues: runtimeLogs.map { ($0.id, $0) })
        for entry in entries {
            mergedByID[entry.id] = entry
        }
        let merged = mergedByID.values
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(80)
        let nextLogs = Array(merged)
        if nextLogs != runtimeLogs {
            runtimeLogs = nextLogs
        }
    }

    private func loadPersistedTunnelLogs() {
        guard let data = UserDefaultsAppProperties.tunnelRuntimeLogs,
              let entries = try? JSONDecoder().decode([PalkaTunnelLogEntry].self, from: data) else {
            return
        }
        mergeRuntimeLogs(entries)
    }

    private static func statusLogName(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid: return "invalid"
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .reasserting: return "reasserting"
        case .disconnecting: return "disconnecting"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }
}
