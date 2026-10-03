import SwiftUI
import WidgetKit

private struct PalkaWidgetEntry: TimelineEntry {
    let date: Date
    let isRunning: Bool
    let strategyName: String
    let availableServices: Int
    let checkedServices: Int
}

private struct PalkaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PalkaWidgetEntry {
        PalkaWidgetEntry(
            date: Date(),
            isRunning: true,
            strategyName: "Balanced",
            availableServices: 2,
            checkedServices: 2
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PalkaWidgetEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PalkaWidgetEntry>) -> Void) {
        let current = entry()
        completion(Timeline(entries: [current], policy: .after(Date().addingTimeInterval(300))))
    }

    private func entry() -> PalkaWidgetEntry {
        let appGroup = Bundle.main.object(forInfoDictionaryKey: "PalkaAppGroupIdentifier") as? String
        let defaults = appGroup.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        let isRunning = defaults.bool(forKey: "byedpiVPNRunning")
        let strategyName = defaults.string(forKey: "activeStrategyName") ?? "MuseDPI"
        var available = 0
        var checked = 0
        if let data = defaults.data(forKey: "MuseDPI.lastDiagnostics.v1"),
           let objects = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            checked = objects.count
            available = objects.filter {
                let status = $0["status"] as? String
                return status == "reachable" || status == "partial"
            }.count
        }
        return PalkaWidgetEntry(
            date: Date(),
            isRunning: isRunning,
            strategyName: strategyName,
            availableServices: available,
            checkedServices: checked
        )
    }
}

private struct PalkaWidgetView: View {
    let entry: PalkaWidgetEntry

    private var prefersRussian: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") == true
    }

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.025, blue: 0.045)
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("MuseDPI")
                        .font(.system(size: 16, weight: .heavy))
                    Spacer()
                    Circle()
                        .fill(entry.isRunning ? Color.green : Color.gray)
                        .frame(width: 9, height: 9)
                }

                Text(entry.isRunning
                     ? (prefersRussian ? "Подключено" : "Connected")
                     : (prefersRussian ? "Отключено" : "Disconnected"))
                    .font(.system(size: 13, weight: .bold))

                Text(entry.strategyName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)

                if entry.checkedServices > 0 {
                    Text("\(entry.availableServices)/\(entry.checkedServices) " + (prefersRussian ? "сервисов доступны" : "services available"))
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer(minLength: 0)

                Label(
                    entry.isRunning
                        ? (prefersRussian ? "Отключить" : "Disconnect")
                        : (prefersRussian ? "Подключить" : "Connect"),
                    systemImage: "power"
                )
                .font(.system(size: 11, weight: .bold))
            }
            .padding(14)
            .foregroundColor(.white)
        }
        .widgetURL(URL(string: "palkadpi://toggle"))
    }
}

struct PalkaStatusWidget: Widget {
    let kind = "PalkaStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PalkaWidgetProvider()) { entry in
            PalkaWidgetView(entry: entry)
        }
        .configurationDisplayName("MuseDPI")
        .description("Connection, strategy, and service availability")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PalkaWidgetBundle: WidgetBundle {
    var body: some Widget {
        PalkaStatusWidget()
    }
}
