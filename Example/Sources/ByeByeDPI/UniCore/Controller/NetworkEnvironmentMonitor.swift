//
//  NetworkEnvironmentMonitor.swift
//  PalkaDPI
//

import Foundation
import Network
import SwiftUI

final class NetworkEnvironmentMonitor: ObservableObject {
    @Published private(set) var kind: PalkaNetworkKind = .other
    @Published private(set) var isExpensive = false
    @Published private(set) var isConstrained = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "MuseDPI.NetworkEnvironment")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let kind: PalkaNetworkKind
            if path.status != .satisfied {
                kind = .offline
            } else if path.usesInterfaceType(.wifi) {
                kind = .wifi
            } else if path.usesInterfaceType(.cellular) {
                kind = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                kind = .wired
            } else {
                kind = .other
            }

            DispatchQueue.main.async {
                self?.kind = kind
                self?.isExpensive = path.isExpensive
                if #available(iOS 13.0, macOS 10.15, tvOS 13.0, *) {
                    self?.isConstrained = path.isConstrained
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
