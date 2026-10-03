//
//  PalkaFeaturesScreen.swift
//  PalkaDPI
//

import Foundation
import SwiftUI
import SwByeDPI

struct AutomationScreen: View {
    @EnvironmentObject private var automation: StrategyAutomationManager
    @EnvironmentObject private var catalog: OnlineStrategyCatalogStore

    var body: some View {
        featureContainer(title: palkaLocalized("palkaAutoTitle")) {
            VStack(alignment: .leading, spacing: 18) {
                featureHeader(
                    title: palkaLocalized("palkaAutoHeading"),
                    text: palkaLocalized("palkaAutoDescription"),
                    icon: "wand.and.stars"
                )

                if automation.isRunning {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(automation.currentStrategyName)
                                    .font(.system(size: 15, weight: .bold))
                                Text(automation.currentStage)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(PalkaDesign.textSecondary)
                            }
                            Spacer()
                            Text("\(automation.completedStrategies)/\(automation.totalStrategies)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(PalkaDesign.textMuted)
                        }
                        ProgressView(
                            value: Double(automation.completedStrategies),
                            total: Double(max(automation.totalStrategies, 1))
                        )
                        .accentColor(PalkaDesign.textPrimary)

                        Button(palkaLocalized("palkaAutoCancel"), action: automation.cancel)
                            .buttonStyle(PalkaSecondaryButtonStyle())
                    }
                    .padding(18)
                    .palkaCard(selected: true)
                } else {
                    Button(action: automation.startAutoSelection) {
                        Label(palkaLocalized("palkaAutoStart"), systemImage: "sparkles")
                    }
                    .buttonStyle(PalkaPrimaryButtonStyle())
                }

                if let best = automation.bestStrategyName {
                    PalkaFeedbackBanner(
                        text: String(format: palkaLocalized("palkaAutoSelectedFormat"), best),
                        kind: .success
                    )
                }
                if let error = automation.errorText {
                    PalkaFeedbackBanner(text: error, kind: .error)
                }
                if let summary = automation.screeningSummary {
                    PalkaFeedbackBanner(text: summary, kind: .success)
                }

                if !automation.scores.isEmpty {
                    PalkaSettingsSection(palkaLocalized("palkaAutoResults")) {
                        ForEach(automation.scores) { score in
                            HStack(spacing: 12) {
                                Image(systemName: score.succeededServices == score.totalServices
                                      ? "checkmark.circle.fill"
                                      : "exclamationmark.circle.fill")
                                    .foregroundColor(score.succeededServices > 0
                                                     ? PalkaDesign.successText
                                                     : PalkaDesign.errorText)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(score.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(scoreDetails(score))
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .foregroundColor(PalkaDesign.textMuted)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .palkaCard()
                        }
                    }
                }

                if !automation.logLines.isEmpty {
                    PalkaSettingsSection(palkaLocalized("palkaAutoLog")) {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(automation.logLines.suffix(40).enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(PalkaDesign.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .palkaCard()
                    }
                }

                if catalog.strategies.isEmpty && catalog.isLoading {
                    HStack(spacing: 10) {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text(palkaLocalized("palkaCatalogLoading"))
                            .font(.system(size: 13, weight: .medium))
                    }
                }
            }
        }
    }
}

struct ServiceSelectionScreen: View {
    @EnvironmentObject private var properties: AppProperties
    @EnvironmentObject private var neManager: NEObservableManager
    @State private var customDomainsText = ""

    var body: some View {
        featureContainer(title: palkaLocalized("palkaServicesTitle")) {
            VStack(alignment: .leading, spacing: 18) {
                featureHeader(
                    title: palkaLocalized("palkaServicesHeading"),
                    text: palkaLocalized("palkaServicesDescription"),
                    icon: "square.grid.2x2.fill"
                )

                if neManager.vpnRunning {
                    PalkaFeedbackBanner(text: palkaLocalized("palkaServicesStopFirst"), kind: .error)
                }

                ForEach(PalkaService.all) { service in
                    let selected = properties.selectedServiceIDs.contains(service.id)
                    Button {
                        toggle(service)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: service.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 42, height: 42)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Text(service.name)
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(selected ? PalkaDesign.successText : PalkaDesign.textDim)
                        }
                        .padding(15)
                        .palkaCard(selected: selected)
                    }
                    .buttonStyle(PalkaPressButtonStyle())
                    .disabled(neManager.vpnRunning)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(palkaLocalized("palkaCustomDomainsTitle"))
                        .font(.system(size: 15, weight: .bold))
                    Text(palkaLocalized("palkaCustomDomainsDescription"))
                        .font(.system(size: 11))
                        .foregroundColor(PalkaDesign.textMuted)
                    TextEditor(text: $customDomainsText)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundColor(PalkaDesign.textPrimary)
                        .frame(minHeight: 110)
                        .padding(8)
                        .background(Color.white.opacity(0.045))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Button(palkaLocalized("palkaCustomDomainsSave")) {
                        properties.customServiceDomains = customDomainsText
                            .components(separatedBy: .newlines)
                    }
                    .buttonStyle(PalkaSecondaryButtonStyle())
                    .disabled(neManager.vpnRunning)
                }
                .padding(16)
                .palkaCard()
            }
        }
        .onAppear {
            customDomainsText = properties.customServiceDomains.joined(separator: "\n")
        }
    }

    private func toggle(_ service: PalkaService) {
        var identifiers = properties.selectedServiceIDs
        if let index = identifiers.firstIndex(of: service.id) {
            guard identifiers.count > 1 else { return }
            identifiers.remove(at: index)
        } else {
            identifiers.append(service.id)
        }
        properties.selectedServiceIDs = identifiers
    }
}

struct DiagnosticsScreen: View {
    @EnvironmentObject private var properties: AppProperties
    @EnvironmentObject private var diagnostics: ServiceDiagnosticsMonitor
    @EnvironmentObject private var network: NetworkEnvironmentMonitor
    @EnvironmentObject private var automation: StrategyAutomationManager

    @State private var showShare = false
    @State private var reportURL: URL? = nil

    var body: some View {
        featureContainer(title: palkaLocalized("palkaDiagnosticsTitle")) {
            VStack(alignment: .leading, spacing: 18) {
                featureHeader(
                    title: palkaLocalized("palkaDiagnosticsHeading"),
                    text: palkaLocalized("palkaDiagnosticsDescription"),
                    icon: "stethoscope"
                )

                Button {
                    diagnostics.refresh(
                        serviceIDs: properties.selectedServiceIDs,
                        customDomains: properties.customServiceDomains,
                        attempts: 3
                    ) { results in
                        automation.evaluateRecovery(results: results)
                    }
                } label: {
                    Label(
                        diagnostics.isRefreshing
                            ? palkaLocalized("palkaServicePingTesting")
                            : palkaLocalized("palkaDiagnosticsRun"),
                        systemImage: "waveform.path.ecg"
                    )
                }
                .buttonStyle(PalkaPrimaryButtonStyle())
                .disabled(diagnostics.isRefreshing)

                ForEach(diagnostics.services) { service in
                    diagnosticCard(service)
                }

                Button {
                    reportURL = PalkaSupportReportBuilder.make(
                        properties: properties,
                        diagnostics: diagnostics.services,
                        network: network
                    )
                    showShare = reportURL != nil
                } label: {
                    Label(palkaLocalized("palkaDiagnosticsExport"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PalkaSecondaryButtonStyle())
            }
        }
#if canImport(UIKit) && !os(tvOS)
        .sheet(isPresented: $showShare) {
            if let reportURL = reportURL {
                ActivityVC(presented: $showShare, activityItems: [reportURL])
                    .ignoresSafeArea(.all, edges: .bottom)
            }
        }
#endif
    }

    private func diagnosticCard(_ service: PalkaServiceProbe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(service.name)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text(diagnosticStatus(service.status))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(diagnosticColor(service.status))
            }

            HStack(spacing: 8) {
                diagnosticMetric("DNS", service.dnsMilliseconds)
                diagnosticMetric("TLS", service.tlsMilliseconds)
                diagnosticMetric("HTTP", service.latencyMilliseconds)
                if service.bulkStalled == true {
                    diagnosticMetricText(
                        palkaLocalized("palkaDiagnosticBulk"),
                        String(format: palkaLocalized("palkaDiagnosticStalledFormat"), service.bulkReceivedKilobytes ?? 0),
                        highlighted: true
                    )
                } else if let kbps = service.bulkKilobytesPerSecond {
                    diagnosticMetricText(palkaLocalized("palkaDiagnosticBulk"), "\(kbps) KB/s", highlighted: false)
                }
            }

            Text("\(service.successfulAttempts)/\(service.totalAttempts) · HTTP \(service.statusCode.map(String.init) ?? "—")")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(PalkaDesign.textMuted)
        }
        .padding(16)
        .palkaCard(selected: service.status == .reachable)
    }

    private func diagnosticMetricText(_ title: String, _ value: String, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 9, weight: .semibold)).foregroundColor(PalkaDesign.textMuted)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(highlighted ? PalkaDesign.errorText : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func diagnosticMetric(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 9, weight: .semibold)).foregroundColor(PalkaDesign.textMuted)
            Text(value.map { "\($0) ms" } ?? "—")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct NetworkProfilesScreen: View {
    @EnvironmentObject private var properties: AppProperties
    @EnvironmentObject private var neManager: NEObservableManager
    @EnvironmentObject private var network: NetworkEnvironmentMonitor

    @State private var message: String? = nil

    var body: some View {
        featureContainer(title: palkaLocalized("palkaNetworkProfilesTitle")) {
            VStack(alignment: .leading, spacing: 18) {
                featureHeader(
                    title: palkaLocalized("palkaNetworkProfilesHeading"),
                    text: palkaLocalized("palkaNetworkProfilesDescription"),
                    icon: network.kind.icon
                )

                PalkaSettingsSection(palkaLocalized("palkaOnDemandSection")) {
                    featureToggle(
                        title: palkaLocalized("palkaOnDemandEnabled"),
                        text: palkaLocalized("palkaOnDemandDescription"),
                        isOn: Binding(get: { properties.onDemandEnabled }, set: { properties.onDemandEnabled = $0 })
                    )
                    featureToggle(
                        title: "Wi‑Fi",
                        text: palkaLocalized("palkaOnDemandWiFi"),
                        isOn: Binding(get: { properties.onDemandWiFiEnabled }, set: { properties.onDemandWiFiEnabled = $0 })
                    )
                    featureToggle(
                        title: palkaLocalized("palkaCellular"),
                        text: palkaLocalized("palkaOnDemandCellular"),
                        isOn: Binding(get: { properties.onDemandCellularEnabled }, set: { properties.onDemandCellularEnabled = $0 })
                    )

                    Button(palkaLocalized("palkaOnDemandSave")) {
                        neManager.configureOnDemand(
                            enabled: properties.onDemandEnabled,
                            includeWiFi: properties.onDemandWiFiEnabled,
                            includeCellular: properties.onDemandCellularEnabled
                        ) { error in
                            DispatchQueue.main.async {
                                message = error?.localizedDescription ?? palkaLocalized("palkaOnDemandSaved")
                            }
                        }
                    }
                    .buttonStyle(PalkaSecondaryButtonStyle())
                }

                PalkaSettingsSection(palkaLocalized("palkaRecoverySection")) {
                    featureToggle(
                        title: palkaLocalized("palkaRecoveryEnabled"),
                        text: palkaLocalized("palkaRecoveryDescription"),
                        isOn: Binding(get: { properties.smartRecoveryEnabled }, set: { properties.smartRecoveryEnabled = $0 })
                    )
                    featureToggle(
                        title: palkaLocalized("palkaQUICBlockEnabled"),
                        text: palkaLocalized("palkaQUICBlockDescription"),
                        isOn: Binding(get: { properties.blockQUICEnabled }, set: { properties.blockQUICEnabled = $0 })
                    )
                }

                PalkaSettingsSection(palkaLocalized("palkaCurrentNetwork")) {
                    HStack(spacing: 12) {
                        Image(systemName: network.kind.icon)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(networkTitle(network.kind)).font(.system(size: 15, weight: .bold))
                            Text(properties.activeStrategyName)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(PalkaDesign.textMuted)
                        }
                        Spacer()
                    }
                    .padding(15)
                    .palkaCard()

                    Button(palkaLocalized("palkaSaveNetworkProfile")) {
                        properties.saveCurrentStrategy(for: network.kind)
                        message = palkaLocalized("palkaNetworkProfileSaved")
                    }
                    .buttonStyle(PalkaSecondaryButtonStyle())
                    .disabled(network.kind == .offline)
                }

                ForEach(properties.networkProfiles) { profile in
                    HStack(spacing: 12) {
                        Image(systemName: profile.networkKind.icon)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(networkTitle(profile.networkKind)).font(.system(size: 14, weight: .bold))
                            Text(profile.strategyName).font(.system(size: 11)).foregroundColor(PalkaDesign.textMuted)
                        }
                        Spacer()
                        Button(palkaLocalized("palkaCatalogApply")) {
                            _ = properties.applyNetworkProfile(for: profile.networkKind)
                        }
                        .buttonStyle(PalkaCompactPrimaryButtonStyle())
                        .disabled(neManager.vpnRunning)
                    }
                    .padding(14)
                    .palkaCard()
                }

                if let message = message {
                    PalkaFeedbackBanner(text: message, kind: .success)
                }
            }
        }
    }
}

struct StrategyHistoryScreen: View {
    @EnvironmentObject private var properties: AppProperties
    @EnvironmentObject private var library: StrategyLibraryStore
    @EnvironmentObject private var neManager: NEObservableManager

    var body: some View {
        featureContainer(title: palkaLocalized("palkaHistoryTitle")) {
            VStack(alignment: .leading, spacing: 18) {
                featureHeader(
                    title: palkaLocalized("palkaHistoryHeading"),
                    text: palkaLocalized("palkaHistoryDescription"),
                    icon: "clock.arrow.circlepath"
                )

                if library.records.isEmpty {
                    Text(palkaLocalized("palkaHistoryEmpty"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(PalkaDesign.textSecondary)
                        .padding(18)
                        .frame(maxWidth: .infinity)
                        .palkaCard()
                }

                ForEach(library.records) { record in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(record.name).font(.system(size: 15, weight: .bold))
                            Spacer()
                            if record.isFavorite {
                                Image(systemName: "star.fill").foregroundColor(PalkaDesign.successText)
                            }
                        }
                        Text(String(
                            format: palkaLocalized("palkaHistoryReliabilityFormat"),
                            Int(record.reliability * 100),
                            record.averageLatencyMilliseconds.map { "\($0) ms" } ?? "—"
                        ))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(PalkaDesign.textMuted)

                        HStack {
                            Button(palkaLocalized("palkaCatalogApply")) {
                                properties.applyCatalogStrategy(
                                    id: record.id,
                                    name: record.name,
                                    commandTemplate: record.commandTemplate
                                )
                            }
                            .buttonStyle(PalkaCompactPrimaryButtonStyle())
                            .disabled(neManager.vpnRunning || record.commandTemplate.isEmpty)

                            Spacer()

                            Button {
                                library.removeHistory(record.id)
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(PalkaPressButtonStyle())
                        }
                    }
                    .padding(15)
                    .palkaCard(selected: record.id == properties.activeStrategyID)
                }
            }
        }
    }
}

private struct FeatureContainer<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ZStack {
            PalkaBackground()
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .padding(.horizontal, PalkaDesign.screenPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
            }
        }
        .foregroundColor(PalkaDesign.textPrimary)
        .navigationTitle(title)
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

private func featureContainer<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
) -> some View {
    FeatureContainer(title: title, content: content)
}

private func featureHeader(title: String, text: String, icon: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
        Image(systemName: icon)
            .font(.system(size: 21, weight: .semibold))
            .frame(width: 48, height: 48)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.65)
                .fixedSize(horizontal: false, vertical: true)
            Text(text)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(PalkaDesign.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private func scoreDetails(_ score: PalkaStrategyTestScore) -> String {
    var parts = [
        "\(score.succeededServices)/\(score.totalServices)",
        score.medianLatencyMilliseconds.map { "\($0) ms" } ?? "—",
    ]
    if score.stalledServices > 0 {
        parts.append(String(format: palkaLocalized("palkaAutoStalledFormat"), score.stalledServices))
    } else if let kbps = score.bulkKilobytesPerSecond {
        parts.append("\(kbps) KB/s")
    }
    return parts.joined(separator: " · ")
}

private func featureToggle(title: String, text: String, isOn: Binding<Bool>) -> some View {
    Toggle(isOn: isOn) {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(text).font(.system(size: 11)).foregroundColor(PalkaDesign.textMuted)
        }
    }
    .toggleStyle(SwitchToggleStyle(tint: PalkaDesign.successText))
    .padding(14)
    .palkaCard()
}

private func diagnosticStatus(_ status: PalkaServiceProbeStatus) -> String {
    switch status {
    case .idle: return palkaLocalized("palkaServicePingIdle")
    case .testing: return palkaLocalized("palkaServicePingTesting")
    case .reachable: return palkaLocalized("palkaServicePingAvailable")
    case .partial: return palkaLocalized("palkaDiagnosticsPartial")
    case .unavailable: return palkaLocalized("palkaServicePingUnavailable")
    }
}

private func diagnosticColor(_ status: PalkaServiceProbeStatus) -> Color {
    switch status {
    case .reachable: return PalkaDesign.successText
    case .partial: return Color.orange
    case .unavailable: return PalkaDesign.errorText
    case .idle, .testing: return PalkaDesign.textMuted
    }
}

private func networkTitle(_ kind: PalkaNetworkKind) -> String {
    switch kind {
    case .wifi: return "Wi‑Fi"
    case .cellular: return palkaLocalized("palkaCellular")
    case .wired: return palkaLocalized("palkaWired")
    case .other: return palkaLocalized("palkaOtherNetwork")
    case .offline: return palkaLocalized("palkaOffline")
    }
}

enum PalkaSupportReportBuilder {
    static func make(
        properties: AppProperties,
        diagnostics: [PalkaServiceProbe],
        network: NetworkEnvironmentMonitor
    ) -> URL? {
        let serviceReports: [[String: Any]] = diagnostics.map { service in
            [
                "service": service.name,
                "status": service.status.rawValue,
                "dns_ms": jsonValue(service.dnsMilliseconds),
                "tls_ms": jsonValue(service.tlsMilliseconds),
                "http_ms": jsonValue(service.latencyMilliseconds),
                "successful_attempts": service.successfulAttempts,
                "total_attempts": service.totalAttempts,
                "http_status": jsonValue(service.statusCode),
            ]
        }
        let report: [String: Any] = [
            "privacy": "No traffic contents, browsing history, device IP, account, or advertising identifiers are included.",
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "app_version": Constants.PSEUDO_BUNDLE_VERSION,
            "app_build": Constants.PSEUDO_BUNDLE_BUILD_NUMBER,
            "engine_version": ByeDPI.versionCode,
            "network_type": network.kind.rawValue,
            "network_expensive": network.isExpensive,
            "network_constrained": network.isConstrained,
            "active_strategy_id": properties.activeStrategyID,
            "active_strategy_name": properties.activeStrategyName,
            "selected_services": properties.selectedServiceIDs,
            "custom_domain_count": properties.customServiceDomains.count,
            "smart_recovery": properties.smartRecoveryEnabled,
            "block_quic": properties.blockQUICEnabled,
            "on_demand": properties.onDemandEnabled,
            "diagnostics": serviceReports,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MuseDPI-support-report.json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func jsonValue(_ value: Int?) -> Any {
        if let value = value {
            return NSNumber(value: value)
        }
        return NSNull()
    }
}
