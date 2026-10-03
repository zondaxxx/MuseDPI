import AppIntents
import NetworkExtension
import SwByeDPI

@available(macOS 13.0, iOS 16.0, tvOS 17.0, *)
///Start network extension VPN (ByeDPI SOCKS to TUN) shortcut
struct StartByeDPIVPNIntent: AppIntent {
    
    static let title = LocalizedStringResource("appIntentStartByeDPIVPNTitle", defaultValue: "Start MuseDPI", table: "AppIntent")
    static let description = IntentDescription(LocalizedStringResource("appIntentStartByeDPIVPNDesc", defaultValue: "Starts MuseDPI and its local packet tunnel", table: "AppIntent"))
    
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        if (UserDefaultsAppProperties.byeDPIVPNRunning) {
#if DEBUG
            print("ByeDPI proxy already running - can't start VPN")
#endif
            return .result(value: false)
        }
        let managers: [NETunnelProviderManager]
        do {
            managers = try await NETunnelProviderManager.loadAllFromPreferences()
        } catch {
#if DEBUG
            print("Load tunnel provider managers error")
            print(error)
#endif
            return .result(value: false)
        }
        if (managers.isEmpty) {
#if DEBUG
            print("Tunnel provider managers array is empty")
#endif
            return .result(value: false)
        }
        let manager = managers[0]
        do {
            try manager.connection.startVPNTunnel(options: NEUtil.generateConnectionParamsFromAppUserDefaults())
        } catch {
#if DEBUG
        print("Start VPN error")
        print(error)
#endif
            return .result(value: false)
        }
        return .result(value: true)
    }
}
