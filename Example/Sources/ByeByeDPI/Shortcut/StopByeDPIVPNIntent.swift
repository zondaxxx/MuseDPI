import AppIntents

@available(macOS 13.0, iOS 16.0, tvOS 17.0, *)
///Stop network extension VPN (ByeDPI SOCKS to TUN) shortcut
struct StopByeDPIVPNIntent: AppIntent {
    
    static let title = LocalizedStringResource("appIntentStopByeDPIVPNTitle", defaultValue: "Stop MuseDPI", table: "AppIntent")
    static let description = IntentDescription(LocalizedStringResource("appIntentStopByeDPIVPNDesc", defaultValue: "Stops MuseDPI and its local packet tunnel", table: "AppIntent"))
    
    func perform() async throws -> some IntentResult {
        _ = NEObservableManager { manager, _ in
            guard let safeManager = manager else {
                return
            }
            safeManager.connection.stopVPNTunnel()
        }
        return .result()
    }
}
