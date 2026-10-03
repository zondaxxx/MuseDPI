//
//  ServiceLatencyMonitor.swift
//  PalkaDPI
//

import Foundation
import SwiftUI

enum PalkaServiceProbeStatus: String, Codable {
    case idle
    case testing
    case reachable
    case partial
    case unavailable
}

struct PalkaServiceProbe: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    var status: PalkaServiceProbeStatus
    var latencyMilliseconds: Int?
    var dnsMilliseconds: Int?
    var tlsMilliseconds: Int?
    var successfulAttempts: Int
    var totalAttempts: Int
    var statusCode: Int?
    var checkedAt: Date?
    var errorText: String?
    /// Bulk (256 KB Range) download on the real delivery host. `nil` when the
    /// service has no bulk target (custom domains) or the probe was not run.
    var bulkKilobytesPerSecond: Int? = nil
    var bulkReceivedKilobytes: Int? = nil
    /// The bulk transfer started (TLS + first bytes arrived) and then froze.
    /// This is the classic TSPU "16-20 KB then silence" signature.
    var bulkStalled: Bool? = nil

    var successRate: Double {
        totalAttempts == 0 ? 0 : Double(successfulAttempts) / Double(totalAttempts)
    }
}

private struct PalkaHTTPProbeMeasurement {
    let succeeded: Bool
    let totalMilliseconds: Int?
    let dnsMilliseconds: Int?
    let tlsMilliseconds: Int?
    let statusCode: Int?
    let errorText: String?
    var isBulk: Bool = false
    var receivedBytes: Int = 0
    var stalled: Bool = false
    var kilobytesPerSecond: Int? = nil
}

private final class PalkaHTTPProbe: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    static let bulkRangeBytes = 256 * 1024
    /// Below this the bulk transfer is not considered proof of a working flow:
    /// TSPU lets the handshake and the first window through before freezing.
    static let bulkMinimumProofBytes = 20 * 1024
    static let bulkStallInterval: TimeInterval = 4

    private let service: PalkaService
    private let isBulk: Bool
    private let completion: (PalkaHTTPProbeMeasurement) -> Void
    private let stateLock = NSLock()
    private let startedAt = Date()
    private var firstByteAt: Date?
    private var lastDataAt: Date?
    private var metrics: URLSessionTaskMetrics?
    private var receivedBytes = 0
    private var receivedData = Data()
    private var expectedBytes: Int?
    private var cancelledForSize = false
    private var completed = false
    private var session: URLSession?
    private var watchdog: DispatchWorkItem?
    private var stallWatchdog: DispatchWorkItem?

    init(
        service: PalkaService,
        timeout: TimeInterval,
        bulk: Bool = false,
        completion: @escaping (PalkaHTTPProbeMeasurement) -> Void
    ) {
        self.service = service
        self.isBulk = bulk
        self.completion = completion
        super.init()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = ["Cache-Control": "no-cache"]
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session

        let targetURL = bulk ? (service.bulkProbeURL ?? service.probeURL) : service.probeURL
        var request = URLRequest(url: targetURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("bytes=0-\(Self.bulkRangeBytes - 1)", forHTTPHeaderField: "Range")
        if bulk {
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
                forHTTPHeaderField: "User-Agent"
            )
        }
        session.dataTask(with: request).resume()

        // A broken packet tunnel can prevent URLSession from ever delivering its timeout
        // callback. Keep an independent deadline so strategy automation always advances.
        let watchdog = DispatchWorkItem { [weak self] in
            self?.finishTimedOut()
        }
        self.watchdog = watchdog
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + timeout + 1,
            execute: watchdog
        )
    }

    func cancel() {
        finish(
            PalkaHTTPProbeMeasurement(
                succeeded: false,
                totalMilliseconds: nil,
                dnsMilliseconds: nil,
                tlsMilliseconds: nil,
                statusCode: nil,
                errorText: URLError(.cancelled).localizedDescription,
                isBulk: isBulk,
                receivedBytes: receivedBytes,
                stalled: false
            ),
            invalidateSession: true
        )
    }

    private func finishTimedOut() {
        let stalled = isBulk && receivedBytes > 0
        finish(
            PalkaHTTPProbeMeasurement(
                succeeded: false,
                totalMilliseconds: nil,
                dnsMilliseconds: nil,
                tlsMilliseconds: nil,
                statusCode: nil,
                errorText: stalled
                    ? "Transfer stalled after \(receivedBytes / 1024) KB"
                    : URLError(.timedOut).localizedDescription,
                isBulk: isBulk,
                receivedBytes: receivedBytes,
                stalled: stalled
            ),
            invalidateSession: true
        )
    }

    private func rearmStallWatchdog() {
        guard isBulk else { return }
        stallWatchdog?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let idle = self.lastDataAt.map { Date().timeIntervalSince($0) } ?? 0
            guard idle >= Self.bulkStallInterval - 0.1 else { return }
            self.finishTimedOut()
        }
        stallWatchdog = item
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + Self.bulkStallInterval,
            execute: item
        )
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse {
            if let range = http.value(forHTTPHeaderField: "Content-Range"),
               let slash = range.lastIndex(of: "/"),
               let total = Int(range[range.index(after: slash)...]) {
                expectedBytes = min(total, Self.bulkRangeBytes)
            } else if http.expectedContentLength > 0 {
                expectedBytes = min(Int(http.expectedContentLength), Self.bulkRangeBytes)
            }
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let now = Date()
        if firstByteAt == nil { firstByteAt = now }
        lastDataAt = now
        receivedBytes += data.count
        if receivedData.count < 128 * 1024 {
            receivedData.append(data.prefix((128 * 1024) - receivedData.count))
        }
        if receivedBytes >= Self.bulkRangeBytes {
            cancelledForSize = true
            dataTask.cancel()
            return
        }
        rearmStallWatchdog()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        self.metrics = metrics
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let statusCode = (task.response as? HTTPURLResponse)?.statusCode
        let transportSucceeded = error == nil || cancelledForSize
        let succeeded: Bool
        if isBulk {
            let proofBytes = min(expectedBytes ?? Self.bulkMinimumProofBytes, Self.bulkMinimumProofBytes)
            succeeded = transportSucceeded
                && service.validatesBulkResponse(response: task.response)
                && receivedBytes >= proofBytes
        } else {
            succeeded = transportSucceeded && service.validatesProbeResponse(
                data: receivedData,
                response: task.response
            )
        }
        let transaction = metrics?.transactionMetrics.last
        let total = max(1, Int(Date().timeIntervalSince(startedAt) * 1000))
        let dns = Self.duration(
            from: transaction?.domainLookupStartDate,
            to: transaction?.domainLookupEndDate
        )
        let tls = Self.duration(
            from: transaction?.secureConnectionStartDate,
            to: transaction?.secureConnectionEndDate
        )
        var kbps: Int? = nil
        if isBulk, succeeded, let first = firstByteAt {
            let seconds = max(0.05, (lastDataAt ?? Date()).timeIntervalSince(first))
            kbps = Int(Double(receivedBytes) / 1024.0 / seconds)
        }
        // Bulk transfer that started delivering bytes and then broke before the
        // proof threshold: the flow was frozen mid-stream, not blocked outright.
        let stalled = isBulk && !succeeded && receivedBytes > 0 && transportSucceeded == false

        finish(
            PalkaHTTPProbeMeasurement(
                succeeded: succeeded,
                totalMilliseconds: succeeded ? total : nil,
                dnsMilliseconds: dns,
                tlsMilliseconds: tls,
                statusCode: statusCode,
                errorText: succeeded ? nil : (error?.localizedDescription ?? "Unexpected service response"),
                isBulk: isBulk,
                receivedBytes: receivedBytes,
                stalled: stalled,
                kilobytesPerSecond: kbps
            ),
            invalidateSession: false
        )
    }

    private func finish(
        _ measurement: PalkaHTTPProbeMeasurement,
        invalidateSession: Bool
    ) {
        stateLock.lock()
        guard !completed else {
            stateLock.unlock()
            return
        }
        completed = true
        let currentSession = session
        session = nil
        let currentWatchdog = watchdog
        watchdog = nil
        let currentStallWatchdog = stallWatchdog
        stallWatchdog = nil
        stateLock.unlock()

        currentWatchdog?.cancel()
        currentStallWatchdog?.cancel()
        if invalidateSession {
            currentSession?.invalidateAndCancel()
        } else {
            currentSession?.finishTasksAndInvalidate()
        }
        completion(measurement)
    }

    private static func duration(from start: Date?, to end: Date?) -> Int? {
        guard let start = start, let end = end else { return nil }
        return max(0, Int(end.timeIntervalSince(start) * 1000))
    }
}

final class ServiceDiagnosticsMonitor: ObservableObject {
    @Published private(set) var services: [PalkaServiceProbe] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastCompletedAt: Date?

    private let defaults = UserDefaults(suiteName: Constants.APP_GROUP_ID) ?? .standard
    private let resultKey = "MuseDPI.lastDiagnostics.v1"
    private var generation = UUID()
    private var probes: [PalkaHTTPProbe] = []

    init() {
        if let data = defaults.data(forKey: resultKey),
           let saved = try? JSONDecoder().decode([PalkaServiceProbe].self, from: data) {
            services = saved
            lastCompletedAt = saved.compactMap(\.checkedAt).max()
        }
    }

    deinit {
        probes.forEach { $0.cancel() }
    }

    func refresh(
        serviceIDs: [String],
        customDomains: [String] = [],
        attempts: Int = 2,
        includeBulk: Bool = true,
        completion: (([PalkaServiceProbe]) -> Void)? = nil
    ) {
        probes.forEach { $0.cancel() }
        probes.removeAll()

        let selected = PalkaService.diagnosticTargets(
            serviceIDs: serviceIDs,
            customDomains: customDomains
        )
        let safeAttempts = min(max(attempts, 1), 4)
        let currentGeneration = UUID()
        generation = currentGeneration
        isRefreshing = true
        services = selected.map {
            PalkaServiceProbe(
                id: $0.id,
                name: $0.name,
                status: .testing,
                latencyMilliseconds: nil,
                dnsMilliseconds: nil,
                tlsMilliseconds: nil,
                successfulAttempts: 0,
                totalAttempts: safeAttempts,
                statusCode: nil,
                checkedAt: nil,
                errorText: nil
            )
        }

        let group = DispatchGroup()
        var measurements: [String: [PalkaHTTPProbeMeasurement]] = [:]
        let measurementQueue = DispatchQueue(label: "MuseDPI.DiagnosticMeasurements")

        for service in selected {
            for _ in 0..<safeAttempts {
                group.enter()
                let probe = PalkaHTTPProbe(service: service, timeout: 7) { measurement in
                    measurementQueue.sync {
                        measurements[service.id, default: []].append(measurement)
                    }
                    group.leave()
                }
                probes.append(probe)
            }
            if includeBulk, service.bulkProbeURL != nil {
                group.enter()
                let bulkProbe = PalkaHTTPProbe(service: service, timeout: 12, bulk: true) { measurement in
                    measurementQueue.sync {
                        measurements[service.id, default: []].append(measurement)
                    }
                    group.leave()
                }
                probes.append(bulkProbe)
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self, self.generation == currentGeneration else { return }
            self.services = selected.map { service in
                let values = measurementQueue.sync { measurements[service.id] ?? [] }
                return self.aggregate(service: service, values: values, attempts: safeAttempts)
            }
            self.isRefreshing = false
            self.lastCompletedAt = Date()
            self.defaults.set(try? JSONEncoder().encode(self.services), forKey: self.resultKey)
            self.probes.removeAll()
            completion?(self.services)
        }
    }

    private func aggregate(
        service: PalkaService,
        values: [PalkaHTTPProbeMeasurement],
        attempts: Int
    ) -> PalkaServiceProbe {
        let small = values.filter { !$0.isBulk }
        let bulk = values.first(where: \.isBulk)
        let successful = small.filter(\.succeeded)
        let bulkSucceeded = bulk?.succeeded
        let bulkStalled = bulk.map { $0.stalled || (!$0.succeeded && $0.receivedBytes > 0) }

        let status: PalkaServiceProbeStatus
        if successful.count == attempts, bulkSucceeded != false {
            status = .reachable
        } else if !successful.isEmpty || bulkSucceeded == true {
            status = .partial
        } else {
            status = .unavailable
        }

        var errorText = values.compactMap(\.errorText).last
        if bulkStalled == true, let bulkError = bulk?.errorText {
            errorText = bulkError
        }

        return PalkaServiceProbe(
            id: service.id,
            name: service.name,
            status: status,
            latencyMilliseconds: median(successful.compactMap(\.totalMilliseconds)),
            dnsMilliseconds: median(successful.compactMap(\.dnsMilliseconds)),
            tlsMilliseconds: median(successful.compactMap(\.tlsMilliseconds)),
            successfulAttempts: successful.count,
            totalAttempts: attempts,
            statusCode: successful.compactMap(\.statusCode).last ?? values.compactMap(\.statusCode).last,
            checkedAt: Date(),
            errorText: errorText,
            bulkKilobytesPerSecond: bulk?.kilobytesPerSecond,
            bulkReceivedKilobytes: bulk.map { $0.receivedBytes / 1024 },
            bulkStalled: bulkStalled
        )
    }

    private func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        if sorted.count % 2 == 1 { return sorted[sorted.count / 2] }
        return (sorted[(sorted.count / 2) - 1] + sorted[sorted.count / 2]) / 2
    }
}
