import AppIntents
import Foundation

@available(macOS 13.0, iOS 16.0, tvOS 17.0, *)
struct CheckPalkaServicesIntent: AppIntent {
    static let title = LocalizedStringResource(
        "appIntentCheckServicesTitle",
        defaultValue: "Check MuseDPI services",
        table: "AppIntent"
    )
    static let description = IntentDescription(LocalizedStringResource(
        "appIntentCheckServicesDesc",
        defaultValue: "Checks whether selected services answer through the current connection",
        table: "AppIntent"
    ))

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let selected = PalkaService.diagnosticTargets(
            serviceIDs: UserDefaultsAppProperties.selectedServiceIDs,
            customDomains: UserDefaultsAppProperties.customServiceDomains
        )
        var available: [String] = []
        var unavailable: [String] = []

        for service in selected {
            var request = URLRequest(url: service.probeURL)
            request.timeoutInterval = 7
            request.cachePolicy = .reloadIgnoringLocalCacheData
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if service.validatesProbeResponse(data: data, response: response) {
                    available.append(service.name)
                } else {
                    unavailable.append(service.name)
                }
            } catch {
                unavailable.append(service.name)
            }
        }

        let summary: String
        if unavailable.isEmpty {
            summary = "MuseDPI: " + available.joined(separator: ", ") + " — OK"
        } else if available.isEmpty {
            summary = "MuseDPI: no response from " + unavailable.joined(separator: ", ")
        } else {
            summary = "Available: " + available.joined(separator: ", ")
                + ". No response: " + unavailable.joined(separator: ", ")
        }
        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 17.0, *)
struct PalkaDPIAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartByeDPIVPNIntent(),
            phrases: ["Start \(.applicationName)", "Connect \(.applicationName)"],
            shortTitle: "Connect MuseDPI",
            systemImageName: "power"
        )
        AppShortcut(
            intent: StopByeDPIVPNIntent(),
            phrases: ["Stop \(.applicationName)", "Disconnect \(.applicationName)"],
            shortTitle: "Disconnect MuseDPI",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: CheckPalkaServicesIntent(),
            phrases: ["Check \(.applicationName)", "Test services with \(.applicationName)"],
            shortTitle: "Check services",
            systemImageName: "waveform.path.ecg"
        )
    }
}
