//
//  PacketTunnelProvider.swift
//  ByeByeDPITun
//
//  Created by developer on 25.03.2026.
//

import CoreFoundation
import SystemConfiguration
import NetworkExtension
import Tun2SocksKit
import Darwin
#if canImport(ByeDPIKit)
import ByeDPIKit
#elseif canImport(ByeDPIKitLib)
import ByeDPIKitLib
#endif
//import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var tunnelStartedAt: Date?
    private var activeSocksAddress = ""
    private var activeSocksPort: UInt16 = 0
    private let runtimeLogLock = NSLock()
    private var runtimeLogs: [[String: Any]] = []
    
    // Redirects Tun2SOCKS, byedpi stdout/stderr to Console.app
    /*fileprivate static func setupLogRedirection() {
        let pipe = Pipe()
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        let logger = Logger(subsystem: Constants.PSEUDO_BUNDLE_ID, category: "BBD-NETUN")
        
        Thread.detachNewThread {
            let fileHandle = pipe.fileHandleForReading
            while true {
                let data = fileHandle.availableData
                if data.isEmpty { break }
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                    // Записываем в системный лог Apple
                    logger.debug("\(output, privacy: .public)")
                }
            }
        }
    }*/
    
    private enum NetworkInterface: UInt8 {
        case none
        case wifi
        case wwan
    }
    
    private static var enabledNetworkInterface: NetworkInterface {
        get {
            var zeroAddress = sockaddr_in()
            zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
            zeroAddress.sin_family = sa_family_t(AF_INET)
            
            guard let reachability = withUnsafePointer(to: &zeroAddress, {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    SCNetworkReachabilityCreateWithAddress(nil, $0)
                }
            }) else {
                return .none
            }
            
            var flags: SCNetworkReachabilityFlags = []
            if (!SCNetworkReachabilityGetFlags(reachability, &flags)) {
                return .none
            }
            
            let isReachable = flags.contains(.reachable)
            let needsConnection = flags.contains(.connectionRequired)
            let canConnectAutomatically = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
            let canConnectWithoutUserInteraction = canConnectAutomatically && !flags.contains(.interventionRequired)
            
            let isNetworkReachable = isReachable && (!needsConnection || canConnectWithoutUserInteraction)
            
            if !isNetworkReachable {
                return .none
            }
            
            #if os(iOS)
            if flags.contains(.isWWAN) {
                return .wwan
            }
            #endif
            
            return .wifi
        }
    }

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        resetRuntimeLogs()
        appendRuntimeLog("Packet Tunnel start requested")
        let cachedConfig = protocolConfiguration as? NETunnelProviderProtocol
        let stockSocksListenIp = options?[UserDefaultsAppKeys.selectedByeDPIListenIpAddrKey.rawValue] as? String ?? cachedConfig?.byeDPIListenIp ?? "127.0.0.1"
        var socksListenIp = stockSocksListenIp
        if (socksListenIp == "127.0.0.1" || socksListenIp == "::1" || socksListenIp == "0.0.0.0" || socksListenIp == "::") {
            // iOS 18+ permits a Packet Tunnel extension to use loopback for its
            // in-process SOCKS server. This avoids cellular-IP hairpinning and
            // interface changes while the tunnel is active.
            if #available(iOS 18.0, *) {
                socksListenIp = "127.0.0.1"
            } else if PacketTunnelProvider.enabledNetworkInterface == .wifi {
                // Older iOS versions require a physical interface address.
                //Wi-Fi or Ethernet -> Get device local IP address
                if let localAddress = getLNWAddress(), !localAddress.isEmpty {
                    socksListenIp = localAddress
                } else {
                    socksListenIp = "0.0.0.0"
                }
            } else if (PacketTunnelProvider.enabledNetworkInterface == .wwan) {
                if let cellularAddress = getCellularAddress(), !cellularAddress.isEmpty {
                   socksListenIp = cellularAddress
                } else {
                    socksListenIp = "0.0.0.0"
                }
            } else {
                socksListenIp = "0.0.0.0"
            }
        }
        
        var port = options?[UserDefaultsAppKeys.selectedByeDPIListenPortKey.rawValue] as? UInt16 ?? cachedConfig?.byeDPIListenPort ?? 10800
        if (port == 0) {
            port = 10800
        }
        var bufSize = options?[UserDefaultsAppKeys.selectedByeDPIBufSizeKey.rawValue] as? UInt32 ?? cachedConfig?.byeDPIBufSize ?? 16384
        if (bufSize == 0) {
            bufSize = 16384
        }
        var maxConn = options?[UserDefaultsAppKeys.selectedByeDPIMaxConn.rawValue] as? UInt16 ?? cachedConfig?.byeDPIMaxConn ?? 512
        if (maxConn == 0) {
            maxConn = 512
        }
        let ttl = options?[UserDefaultsAppKeys.selectedByeDPITTL.rawValue] as? UInt8 ?? cachedConfig?.byeDPITTL
        let noDomain = options?[UserDefaultsAppKeys.byeDPIRestrictDomainResolve.rawValue] as? Bool ?? cachedConfig?.byeDPINoDomains ?? false
        let noUDP = options?[UserDefaultsAppKeys.byeDPIRestrictUDP.rawValue] as? Bool ?? cachedConfig?.byeDPINoUDP ?? false
        let logLevelRaw = options?[UserDefaultsAppKeys.selectedbyeDPILogLevel.rawValue] as? UInt8 ?? cachedConfig?.byeDPILogLevel
        var args: [String] = [
            "-i", socksListenIp,
            "-p", String(port),
            "-b", String(bufSize),
            "-c", String(maxConn)
        ]
        if let safeTtl = ttl, safeTtl != 0 {
            args.append(contentsOf: ["-g", String(safeTtl)])
        }
        if (noDomain) {
            args.append("-N")
        }
        if (noUDP) {
            args.append("-U")
        }
        if let safeLogLevel = logLevelRaw {
            args.append(contentsOf: ["-x", String(safeLogLevel)])
        }
        
        if let safeArgs = options?[UserDefaultsAppKeys.selectedByeDPICmdArgsKey.rawValue] as? [String] ?? cachedConfig?.byeDPICmdArgs, !safeArgs.isEmpty {
            args = safeArgs
            Self.replaceOption(in: &args, names: ["-i", "--ip"], value: socksListenIp)
            Self.replaceOption(in: &args, names: ["-p", "--port"], value: String(port))
        }

        appendRuntimeLog("SOCKS endpoint: \(socksListenIp):\(port)")
        appendRuntimeLog("ByeDPI args: \(Self.logSafeArgs(args))")
        
        let tunMtu = options?[UserDefaultsAppKeys.selectedTunMtuKey.rawValue] as? UInt16 ?? cachedConfig?.tunMtu ?? 1500
        let tunIpAddr = "10.0.0.1"
        //iOS <10 - ~5mb memory max
        //iOS 10..14 - 15 mb memory max
        //iOS 15+ - 50 mb memory max
        //iOS Low memory usage tips - https://github.com/heiher/hev-socks5-tunnel?tab=readme-ov-file#low-memory-usage
        let tun2SocksConfigYAML = """
tunnel:
  mtu: \(tunMtu)

socks5:
  port: \(port)
  address: \(socksListenIp)
  udp: 'udp'

misc:
  task-stack-size: 24576 # 20480 + tcp-buffer-size 
  tcp-buffer-size: 4096 
  max-session-count: 1200 
  connect-timeout: 5000
  tcp-read-write-timeout: 300000
  udp-read-write-timeout: 30000
  log-level: error
"""
#if DEBUG
        //args.insert("-x2", at: 0)
        //tun2SocksConfigYAML += "\n  log-file: stdout\n  log-level: debug"
        //PacketTunnelProvider.setupLogRedirection()
#endif
        
        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: socksListenIp)
        tunnelSettings.mtu = NSNumber(integerLiteral: Int(tunMtu))
        //Set default DNS
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4", "1.1.1.1"])
        dnsSettings.matchDomains = [""]
        tunnelSettings.dnsSettings = dnsSettings
        if let safeDnsAddr = options?[UserDefaultsAppKeys.selectedDnsOverAddrKey.rawValue] as? String ?? cachedConfig?.dnsOverAddr, !safeDnsAddr.isEmpty {
            if (safeDnsAddr.hasPrefix("http") || safeDnsAddr.split(separator: ".").count != 4) {
                //DoH or DoT
                if let safeResolvedServers = options?[UserDefaultsAppKeys.resolvedDnsServersKey.rawValue] as? [String] ?? cachedConfig?.resolvedDnsServers, !safeResolvedServers.isEmpty {
                    if (safeDnsAddr.hasPrefix("http")) {
                        //DoH
                        let dohSettings = NEDNSOverHTTPSSettings(servers: safeResolvedServers)
                        if let safeUrl = URL(string: safeDnsAddr) {
                            dohSettings.serverURL = safeUrl
                            dohSettings.matchDomains = [""]
                            tunnelSettings.dnsSettings = dohSettings
                        }
                    } else {
                        //DoT
                        let dotSettings = NEDNSOverTLSSettings(servers: safeResolvedServers)
                        dotSettings.serverName = safeDnsAddr
                        dotSettings.matchDomains = [""]
                        tunnelSettings.dnsSettings = dotSettings
                    }
                }
            } else {
                //General plain DNS
                let dnsSettings = NEDNSSettings(servers: [safeDnsAddr])
                dnsSettings.matchDomains = [""]
                tunnelSettings.dnsSettings = dnsSettings
            }
        }
        let ipv4Settings = NEIPv4Settings(addresses: [tunIpAddr], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [
            NEIPv4Route.default()
        ]
        ipv4Settings.excludedRoutes = [
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "10.0.0.0",    subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "100.64.0.0",  subnetMask: "255.192.0.0"),
            
            // Google DNS
            NEIPv4Route(destinationAddress: "8.8.8.8", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "8.8.4.4", subnetMask: "255.255.255.255"),
            // Cloudflare DNS
            NEIPv4Route(destinationAddress: "1.1.1.1", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "1.0.0.1", subnetMask: "255.255.255.255"),
            // Quad9 DNS
            NEIPv4Route(destinationAddress: "9.9.9.9", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "149.112.112.112", subnetMask: "255.255.255.255"),
            // Comss DNS
            NEIPv4Route(destinationAddress: "83.220.169.155", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "195.133.25.16", subnetMask: "255.255.255.255"),
            // Adguard DNS
            NEIPv4Route(destinationAddress: "94.140.14.14", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "94.140.14.15", subnetMask: "255.255.255.255"),
        ]
        if (socksListenIp != "0.0.0.0") {
            ipv4Settings.excludedRoutes?.append(NEIPv4Route(destinationAddress: socksListenIp, subnetMask: "255.255.255.255"))
        }
        tunnelSettings.ipv4Settings = ipv4Settings

        // Capture IPv6 as well. Without this route, IPv6-capable apps can bypass
        // the local DPI strategy on dual-stack Wi-Fi and cellular networks.
        let ipv6Settings = NEIPv6Settings(
            addresses: ["fd00::1"],
            networkPrefixLengths: [64]
        )
        ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        tunnelSettings.ipv6Settings = ipv6Settings
    
        let tun2SocksConfig = Socks5Tunnel.Config.string(content: tun2SocksConfigYAML)
        
        let launchArgs = args
        let launchSocksAddress = socksListenIp
        let launchSocksPort = port

        setTunnelNetworkSettings(tunnelSettings) { setErr in
            if let safeSetErr = setErr {
                self.appendRuntimeLog("Network settings failed: \(safeSetErr.localizedDescription)", level: "error")
                completionHandler(safeSetErr)
                return
            }
            self.appendRuntimeLog("Network settings applied (MTU \(tunMtu), IPv4 + IPv6)")
            Task(priority: .high) {
                if let byeDPIStartErr = await ByeDPI.start(args: launchArgs) {
                    self.appendRuntimeLog("ByeDPI failed: \(byeDPIStartErr.localizedDescription)", level: "error")
                    completionHandler(byeDPIStartErr)
                    UserDefaultsAppProperties.byeDPIVPNRunning = false
                    if let safeCenter = CFNotificationCenterGetDarwinNotifyCenter() {
                        CFNotificationCenterPostNotification(safeCenter, .byeDPIVpnStopped, nil, nil, true)
                    }
                    return
                }
                self.appendRuntimeLog("ByeDPI listener started")
                if let healthError = self.verifyLocalSocks5(
                    address: launchSocksAddress,
                    port: launchSocksPort
                ) {
                    self.appendRuntimeLog("SOCKS5 handshake failed: \(healthError.localizedDescription)", level: "error")
                    _ = ByeDPI.forceStop()
                    UserDefaultsAppProperties.byeDPIVPNRunning = false
                    completionHandler(healthError)
                    return
                }
                self.appendRuntimeLog("SOCKS5 handshake passed", level: "success")
                let hevSocksStartOpCode = await Socks5Tunnel.run(with: tun2SocksConfig)
                if (hevSocksStartOpCode == 0) {
                    self.activeSocksAddress = launchSocksAddress
                    self.activeSocksPort = launchSocksPort
                    self.tunnelStartedAt = Date()
                    UserDefaultsAppProperties.byeDPIVPNRunning = true
                    if let safeCenter = CFNotificationCenterGetDarwinNotifyCenter() {
                        CFNotificationCenterPostNotification(safeCenter, .byeDPIVpnStarted, nil, nil, true)
                    }
                    self.appendRuntimeLog("tun2socks started; tunnel is ready", level: "success")
                    completionHandler(nil)
                    return
                }
                self.appendRuntimeLog("tun2socks failed with code \(hevSocksStartOpCode)", level: "error")
                _ = ByeDPI.forceStop()
                UserDefaultsAppProperties.byeDPIVPNRunning = false
                if let safeCenter = CFNotificationCenterGetDarwinNotifyCenter() {
                    CFNotificationCenterPostNotification(safeCenter, .byeDPIVpnStopped, nil, nil, true)
                }
                completionHandler(NSError(domain: NEVPNErrorDomain, code: Int(hevSocksStartOpCode)))
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        appendRuntimeLog("Packet Tunnel stopping (reason \(reason.rawValue))")
        UserDefaultsAppProperties.byeDPIVPNRunning = false
        if let safeCenter = CFNotificationCenterGetDarwinNotifyCenter() {
            CFNotificationCenterPostNotification(safeCenter, .byeDPIVpnStopped, nil, nil, true)
        }
        Socks5Tunnel.stop()
        tunnelStartedAt = nil
        if (ByeDPI.proxyStarted) {
            _ = ByeDPI.forceStop()
        }
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let handler = completionHandler else { return }
        let stats = Socks5Tunnel.stats
        let payload: [String: Any] = [
            "coreRunning": ByeDPI.proxyStarted,
            "socksAddress": activeSocksAddress,
            "socksPort": Int(activeSocksPort),
            "uptimeSeconds": tunnelStartedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0,
            "upPackets": stats.up.packets,
            "upBytes": stats.up.bytes,
            "downPackets": stats.down.packets,
            "downBytes": stats.down.bytes,
            "logs": runtimeLogSnapshot(),
        ]
        handler(try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]))
    }
    
    // sleep/wake are power notifications: the tunnel, tun2socks and the ByeDPI
    // listener all stay alive. Flipping byeDPIVPNRunning here made the widget
    // and the home screen report "disconnected" on every screen lock.
    override func sleep(completionHandler: @escaping () -> Void) {
        appendRuntimeLog("Device sleep notification received; tunnel stays up")
        completionHandler()
    }
    
    override func wake() {
        appendRuntimeLog("Device wake notification received")
        if ByeDPI.proxyStarted, !UserDefaultsAppProperties.byeDPIVPNRunning {
            UserDefaultsAppProperties.byeDPIVPNRunning = true
            if let safeCenter = CFNotificationCenterGetDarwinNotifyCenter() {
                CFNotificationCenterPostNotification(safeCenter, .byeDPIVpnStarted, nil, nil, true)
            }
        }
    }

    private static func replaceOption(
        in args: inout [String],
        names: [String],
        value: String
    ) {
        if let index = args.firstIndex(where: { names.contains($0) }), index + 1 < args.count {
            args[index + 1] = value
            return
        }
        guard let preferredName = names.first else { return }
        args.insert(contentsOf: [preferredName, value], at: 0)
    }

    private static func logSafeArgs(_ args: [String]) -> String {
        let joined = args.joined(separator: " ")
        guard joined.count > 420 else { return joined }
        return String(joined.prefix(420)) + "…"
    }

    private func resetRuntimeLogs() {
        runtimeLogLock.lock()
        runtimeLogs.removeAll(keepingCapacity: true)
        runtimeLogLock.unlock()
        UserDefaultsAppProperties.tunnelRuntimeLogs = try? JSONSerialization.data(
            withJSONObject: [],
            options: []
        )
    }

    private func appendRuntimeLog(_ message: String, level: String = "info") {
        let entry: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "level": level,
            "message": message,
        ]
        runtimeLogLock.lock()
        runtimeLogs.append(entry)
        if runtimeLogs.count > 80 {
            runtimeLogs.removeFirst(runtimeLogs.count - 80)
        }
        let snapshot = runtimeLogs
        runtimeLogLock.unlock()
        UserDefaultsAppProperties.tunnelRuntimeLogs = try? JSONSerialization.data(
            withJSONObject: snapshot,
            options: [.sortedKeys]
        )
    }

    private func runtimeLogSnapshot() -> [[String: Any]] {
        runtimeLogLock.lock()
        let snapshot = runtimeLogs
        runtimeLogLock.unlock()
        return snapshot
    }

    private func verifyLocalSocks5(address: String, port: UInt16) -> Error? {
        let socketFD = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            return NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { Darwin.close(socketFD) }

        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        _ = withUnsafePointer(to: &timeout) {
            Darwin.setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, $0, socklen_t(MemoryLayout<timeval>.size))
        }
        _ = withUnsafePointer(to: &timeout) {
            Darwin.setsockopt(socketFD, SOL_SOCKET, SO_SNDTIMEO, $0, socklen_t(MemoryLayout<timeval>.size))
        }

        var socketAddress = sockaddr_in()
        socketAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        socketAddress.sin_family = sa_family_t(AF_INET)
        socketAddress.sin_port = in_port_t(port).bigEndian
        guard inet_pton(AF_INET, address, &socketAddress.sin_addr) == 1 else {
            return NSError(
                domain: "MuseDPI.Tunnel",
                code: 2001,
                userInfo: [NSLocalizedDescriptionKey: "Invalid local SOCKS address: \(address)"]
            )
        }

        let connectResult = withUnsafePointer(to: &socketAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connectResult == 0 else {
            return NSError(
                domain: "MuseDPI.Tunnel",
                code: 2002,
                userInfo: [NSLocalizedDescriptionKey: "ByeDPI SOCKS listener is unreachable (errno \(errno))"]
            )
        }

        let greeting: [UInt8] = [0x05, 0x01, 0x00]
        let sent = greeting.withUnsafeBytes {
            Darwin.send(socketFD, $0.baseAddress, $0.count, 0)
        }
        guard sent == greeting.count else {
            return NSError(
                domain: "MuseDPI.Tunnel",
                code: 2003,
                userInfo: [NSLocalizedDescriptionKey: "ByeDPI rejected the SOCKS greeting"]
            )
        }

        var response = [UInt8](repeating: 0, count: 2)
        let received = response.withUnsafeMutableBytes {
            Darwin.recv(socketFD, $0.baseAddress, $0.count, 0)
        }
        guard received == 2, response == [0x05, 0x00] else {
            return NSError(
                domain: "MuseDPI.Tunnel",
                code: 2004,
                userInfo: [NSLocalizedDescriptionKey: "ByeDPI SOCKS handshake failed"]
            )
        }
        return nil
    }
    
    func getLNWAddress() -> String? {
        var address: String?

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if (!name.hasPrefix("en")) {
                    // Not Wi-Fi -> Skip
                    continue
                }
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST)
                address = String(cString: hostname)
                if (name == "en0") {
                    break
                }
            }
        }
        freeifaddrs(ifaddr)

        return address
    }
    
    func getCellularAddress() -> String? {
        var address: String?

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if (!name.hasPrefix("pdp_ip")) {
                    // Not cellular -> Skip
                    continue
                }
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST)
                address = String(cString: hostname)
                if (name == "pdp_ip0") {
                    break
                }
            }
        }
        freeifaddrs(ifaddr)

        return address
    }
}
