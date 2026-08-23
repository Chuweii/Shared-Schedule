import Foundation
import MetricKit

/// Untested boundary glue — the only MetricKit import in the codebase.
/// MetricKit payload types have no public initializers, so payloads are
/// converted to owned `CrashReport` values immediately; everything
/// downstream of that conversion is testable.
///
/// Registers itself with `MXMetricManager` for the app's lifetime.
/// `didReceive` arrives on a MetricKit background queue, hence the
/// `nonisolated` class and the hop into the use case via `Task`.
nonisolated final class MetricKitCrashSubscriber: NSObject, MXMetricManagerSubscriber {
    private let recordUseCase: any RecordCrashReportsUseCaseProtocol

    init(recordUseCase: any RecordCrashReportsUseCaseProtocol) {
        self.recordUseCase = recordUseCase
        super.init()
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let reports = payloads.flatMap { payload in
            (payload.crashDiagnostics ?? []).map { diagnostic in
                CrashReport(
                    id: UUID(),
                    timeStampBegin: payload.timeStampBegin,
                    timeStampEnd: payload.timeStampEnd,
                    appVersion: diagnostic.applicationVersion,
                    osVersion: diagnostic.metaData.osVersion,
                    jsonRepresentation: diagnostic.jsonRepresentation()
                )
            }
        }
        guard !reports.isEmpty else { return }
        let useCase = recordUseCase
        Task { await useCase.recordCrashReports(reports) }
    }
}
