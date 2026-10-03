//
//  OnlineStrategyCatalogScreen.swift
//  PalkaDPI
//

import Foundation
import SwiftUI
import SwByeDPI
import CryptoKit

struct OnlineStrategyCatalogDocument: Decodable {
    let schemaVersion: Int
    let generation: Int
    let updatedAt: String
    let minimumAppVersion: String
    let minimumEngineVersion: String
    let revokedStrategyIDs: [String]
    let strategies: [OnlineStrategy]
}

struct OnlineStrategy: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let nameRu: String?
    let summary: String
    let summaryRu: String?
    let services: [String]
    let stability: String
    let stabilityRu: String?
    let sourceName: String
    let sourceURL: String
    let commandArgs: [String]
    let minimumAppVersion: String?
    let minimumEngineVersion: String?
    let deprecated: Bool?

    private var prefersRussian: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") == true
    }

    var displayName: String {
        prefersRussian ? (nameRu ?? name) : name
    }

    var displaySummary: String {
        prefersRussian ? (summaryRu ?? summary) : summary
    }

    var displayStability: String {
        prefersRussian ? (stabilityRu ?? stability) : stability
    }

    var searchableText: String {
        ([name, nameRu ?? "", summary, summaryRu ?? "", stability, stabilityRu ?? "", sourceName] + services)
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    var sourceLink: URL? {
        guard let url = URL(string: sourceURL), url.scheme == "https" else { return nil }
        return url
    }

    func resolvedCommandArgs(serviceIDs: [String], customDomains: [String] = []) -> [String]? {
        guard !commandArgs.isEmpty, commandArgs.count <= 160 else { return nil }

        var resolved: [String] = []
        for argument in commandArgs {
            if argument == PalkaPreset.catalogTargetsPlaceholder {
                resolved.append(PalkaService.targetsArgument(for: serviceIDs, customDomains: customDomains))
                continue
            }

            guard argument.count <= 4096,
                  !argument.contains("\n"),
                  !argument.contains("\r"),
                  !argument.contains("\0") else {
                return nil
            }
            resolved.append(argument)
        }

        let validated = SBDConfig(commandArgs: resolved).validatedCmdArgs
        return validated.isEmpty ? nil : validated
    }
}

private struct PalkaCatalogCacheEntry: Codable {
    let data: Data
    let signature: Data
    let savedAt: Date
}

final class OnlineStrategyCatalogStore: ObservableObject {
    @Published private(set) var strategies: [OnlineStrategy] = []
    @Published private(set) var updatedAt = ""
    @Published private(set) var generation = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isUsingCache = false
    @Published private(set) var errorText: String? = nil

    private static let cacheKey = "MuseDPI.onlineStrategyCatalog.v2"
    private static let maximumCatalogSize = 512 * 1024

    private let defaults = UserDefaults(suiteName: Constants.APP_GROUP_ID) ?? .standard
    private var tasks: [URLSessionDataTask] = []
    private var cacheEntries: [PalkaCatalogCacheEntry] = []

    init() {
        if let cacheData = defaults.data(forKey: Self.cacheKey),
           let entries = try? JSONDecoder().decode([PalkaCatalogCacheEntry].self, from: cacheData) {
            cacheEntries = entries
            if let latest = entries.first {
                _ = apply(data: latest.data, signature: latest.signature, isCache: true)
            }
        }
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }

    var canUsePreviousVersion: Bool { cacheEntries.count > 1 }

    func load() {
        guard !isLoading else { return }

        isLoading = true
        errorText = nil

        tasks.forEach { $0.cancel() }
        tasks.removeAll()

        var signatureRequest = URLRequest(
            url: Constants.strategyCatalogSignatureURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 10
        )
        signatureRequest.setValue("text/plain", forHTTPHeaderField: "Accept")

        let signatureTask = URLSession.shared.dataTask(with: signatureRequest) { [weak self] signatureText, response, error in
            guard let self = self else { return }
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let signatureText = signatureText,
                  let signatureString = String(data: signatureText, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  let signature = Data(base64Encoded: signatureString) else {
                DispatchQueue.main.async { self.finishWithNetworkError(error) }
                return
            }

            var catalogRequest = URLRequest(
                url: Constants.strategyCatalogURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 10
            )
            catalogRequest.setValue("application/json", forHTTPHeaderField: "Accept")

            let catalogTask = URLSession.shared.dataTask(with: catalogRequest) { [weak self] data, catalogResponse, catalogError in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false

                    guard catalogError == nil,
                          let catalogHTTP = catalogResponse as? HTTPURLResponse,
                          catalogHTTP.statusCode == 200,
                          let data = data,
                          data.count <= Self.maximumCatalogSize,
                          self.apply(data: data, signature: signature, isCache: false) else {
                        self.errorText = catalogError?.localizedDescription
                            ?? palkaLocalized("palkaCatalogInvalidSignature")
                        return
                    }

                    self.saveVerified(data: data, signature: signature)
                }
            }
            self.tasks.append(catalogTask)
            catalogTask.resume()
        }
        tasks.append(signatureTask)
        signatureTask.resume()
    }

    func usePreviousVersion() {
        guard cacheEntries.count > 1 else { return }
        let previous = cacheEntries[1]
        if apply(data: previous.data, signature: previous.signature, isCache: true) {
            cacheEntries.remove(at: 1)
            cacheEntries.insert(previous, at: 0)
            persistCache()
        }
    }

    private func finishWithNetworkError(_ error: Error?) {
        isLoading = false
        errorText = error?.localizedDescription ?? palkaLocalized("palkaCatalogInvalidSignature")
    }

    private func saveVerified(data: Data, signature: Data) {
        let entry = PalkaCatalogCacheEntry(data: data, signature: signature, savedAt: Date())
        cacheEntries.removeAll { $0.data == data }
        cacheEntries.insert(entry, at: 0)
        cacheEntries = Array(cacheEntries.prefix(3))
        persistCache()
    }

    private func persistCache() {
        defaults.set(
            try? JSONEncoder().encode(cacheEntries),
            forKey: Self.cacheKey
        )
    }

    private func verify(data: Data, signature: Data) -> Bool {
        guard let keyData = Data(base64Encoded: Constants.strategyCatalogPublicKeyBase64),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else {
            return false
        }
        return key.isValidSignature(signature, for: data)
    }

    @discardableResult
    private func apply(data: Data, signature: Data, isCache: Bool) -> Bool {
        guard verify(data: data, signature: signature),
              data.count <= Self.maximumCatalogSize,
              let document = try? JSONDecoder().decode(OnlineStrategyCatalogDocument.self, from: data),
              document.schemaVersion == 2,
              document.generation > 0,
              !document.strategies.isEmpty,
              document.strategies.count <= 100,
              version(Constants.PSEUDO_BUNDLE_VERSION, isAtLeast: document.minimumAppVersion),
              version(ByeDPI.versionCode, isAtLeast: document.minimumEngineVersion) else {
            return false
        }

        let allIDs = document.strategies.map(\.id)
        guard Set(allIDs).count == allIDs.count else { return false }

        if !isCache {
            let highestCachedGeneration = cacheEntries.compactMap { entry in
                try? JSONDecoder().decode(OnlineStrategyCatalogDocument.self, from: entry.data).generation
            }.max() ?? 0
            guard document.generation >= highestCachedGeneration else { return false }
        }

        let revoked = Set(document.revokedStrategyIDs)
        let compatible = document.strategies.filter { strategy in
            !revoked.contains(strategy.id) &&
            strategy.deprecated != true &&
            version(Constants.PSEUDO_BUNDLE_VERSION, isAtLeast: strategy.minimumAppVersion ?? "0") &&
            version(ByeDPI.versionCode, isAtLeast: strategy.minimumEngineVersion ?? "0")
        }
        let uniqueIDs = Set(compatible.map(\.id))
        guard !compatible.isEmpty,
              uniqueIDs.count == compatible.count,
              compatible.allSatisfy({
                  !$0.id.isEmpty &&
                  !$0.name.isEmpty &&
                  $0.sourceLink != nil &&
                  $0.resolvedCommandArgs(serviceIDs: PalkaService.defaultIDs) != nil
              }) else {
            return false
        }

        strategies = compatible
        updatedAt = document.updatedAt
        generation = document.generation
        isUsingCache = isCache
        errorText = nil
        return true
    }

    private func version(_ current: String, isAtLeast required: String) -> Bool {
        let lhs = current.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = required.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return true
    }
}

struct OnlineStrategyCatalogScreen: View {
    @EnvironmentObject private var properties: AppProperties
    @EnvironmentObject private var neManager: NEObservableManager

    @EnvironmentObject private var catalog: OnlineStrategyCatalogStore
    @EnvironmentObject private var library: StrategyLibraryStore
    @State private var searchText = ""
    @State private var appliedStrategyID: String? = nil

    private var filteredStrategies: [OnlineStrategy] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        guard !query.isEmpty else { return catalog.strategies }
        return catalog.strategies.filter { $0.searchableText.contains(query) }
    }

    var body: some View {
        ZStack {
            PalkaBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    catalogHeader
                        .palkaEntrance()
                    searchField
                        .palkaEntrance(delay: 0.05)

                    if neManager.vpnRunning {
                        PalkaFeedbackBanner(
                            text: palkaLocalized("palkaCatalogStopFirst"),
                            kind: .error
                        )
                    }

                    if let errorText = catalog.errorText {
                        PalkaFeedbackBanner(
                            text: catalog.strategies.isEmpty
                                ? errorText
                                : palkaLocalized("palkaCatalogOfflineCache"),
                            kind: .error
                        )
                    }

                    if catalog.canUsePreviousVersion {
                        Button {
                            catalog.usePreviousVersion()
                        } label: {
                            Label(palkaLocalized("palkaCatalogRollback"), systemImage: "arrow.uturn.backward.circle")
                        }
                        .buttonStyle(PalkaSecondaryButtonStyle())
                    }

                    if catalog.isLoading && catalog.strategies.isEmpty {
                        loadingCard
                    } else if filteredStrategies.isEmpty {
                        emptyCard
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredStrategies.enumerated()), id: \.element.id) { index, strategy in
                                strategyCard(strategy)
                                    .palkaEntrance(delay: min(Double(index) * 0.05, 0.30))
                            }
                        }
                    }
                }
                .padding(.horizontal, PalkaDesign.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .foregroundColor(PalkaDesign.textPrimary)
        .navigationTitle(palkaLocalized("palkaCatalogTitle"))
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onAppear {
            catalog.load()
        }
    }

    private var catalogHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(palkaLocalized("palkaCatalogHeading"))
                    .font(.system(size: 24, weight: .heavy))
                    .tracking(-0.7)

                Text(catalogStatusText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(PalkaDesign.textSecondary)
            }

            Spacer(minLength: 8)

            Button(action: catalog.load) {
                Group {
                    if catalog.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: PalkaDesign.textPrimary))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
                .overlay(Circle().stroke(PalkaDesign.border, lineWidth: 1))
            }
            .buttonStyle(PalkaPressButtonStyle())
            .disabled(catalog.isLoading)
            .accessibilityLabel(palkaLocalized("palkaCatalogRefresh"))
        }
    }

    private var catalogStatusText: String {
        guard !catalog.updatedAt.isEmpty else {
            return palkaLocalized("palkaCatalogInternetSource")
        }
        let format = catalog.isUsingCache
            ? palkaLocalized("palkaCatalogCachedFormat")
            : palkaLocalized("palkaCatalogUpdatedFormat")
        return String(format: format, catalog.updatedAt)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(PalkaDesign.textMuted)

            TextField(palkaLocalized("palkaCatalogSearchPlaceholder"), text: $searchText)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(PalkaDesign.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(PalkaDesign.textMuted)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PalkaPressButtonStyle())
                .accessibilityLabel(palkaLocalized("palkaCatalogClearSearch"))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, searchText.isEmpty ? 14 : 0)
        .frame(minHeight: 52)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PalkaDesign.border, lineWidth: 1)
        )
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: PalkaDesign.textPrimary))
            Text(palkaLocalized("palkaCatalogLoading"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(PalkaDesign.textSecondary)
            Spacer()
        }
        .padding(18)
        .palkaCard()
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(PalkaDesign.textMuted)
            Text(palkaLocalized("palkaCatalogEmpty"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(PalkaDesign.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .palkaCard()
    }

    private func strategyCard(_ strategy: OnlineStrategy) -> some View {
        let isActive = properties.activeStrategyID == strategy.id
        let wasJustApplied = appliedStrategyID == strategy.id

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(strategy.displayName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(PalkaDesign.textPrimary)

                    Text(strategy.displaySummary)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(PalkaDesign.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(spacing: 6) {
                    if isActive || wasJustApplied {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(PalkaDesign.successText)
                    }
                    Button {
                        library.toggleFavorite(strategy: strategy)
                    } label: {
                        Image(systemName: library.isFavorite(strategy.id) ? "star.fill" : "star")
                            .foregroundColor(library.isFavorite(strategy.id)
                                             ? PalkaDesign.successText
                                             : PalkaDesign.textMuted)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PalkaPressButtonStyle())
                    .accessibilityLabel(palkaLocalized("palkaCatalogFavorite"))
                }
            }

            HStack(spacing: 8) {
                catalogTag(strategy.services.joined(separator: " + "))
                catalogTag(strategy.displayStability)
            }

            HStack(spacing: 12) {
                if let sourceLink = strategy.sourceLink {
                    Link(destination: sourceLink) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                            Text(strategy.sourceName)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(PalkaDesign.textMuted)
                        .frame(minHeight: 44)
                    }
                }

                Spacer(minLength: 8)

                Button {
                    apply(strategy)
                } label: {
                    Text(isActive || wasJustApplied
                         ? palkaLocalized("palkaCatalogApplied")
                         : palkaLocalized("palkaCatalogApply"))
                }
                .buttonStyle(PalkaCompactPrimaryButtonStyle())
                .disabled(neManager.vpnRunning || isActive)
            }
        }
        .padding(16)
        .palkaCard(selected: isActive || wasJustApplied)
    }

    private func catalogTag(_ text: String) -> some View {
        Text(text.uppercased(with: Locale.current))
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.45)
            .foregroundColor(PalkaDesign.textSecondary)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Color.white.opacity(0.055))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private func apply(_ strategy: OnlineStrategy) {
        guard !neManager.vpnRunning,
              strategy.resolvedCommandArgs(
                serviceIDs: properties.selectedServiceIDs,
                customDomains: properties.customServiceDomains
              ) != nil else { return }

        properties.applyCatalogStrategy(
            id: strategy.id,
            name: strategy.displayName,
            commandTemplate: strategy.commandArgs
        )
        withAnimation(.easeOut(duration: 0.18)) {
            appliedStrategyID = strategy.id
        }
    }
}

#if DEBUG
#Preview {
    NavigationView {
        OnlineStrategyCatalogScreen()
    }
    .preferredColorScheme(.dark)
    .environmentObject(previewProperties)
    .environmentObject(previewNeManager)
    .environmentObject(OnlineStrategyCatalogStore())
    .environmentObject(previewStrategyLibrary)
}
#endif
