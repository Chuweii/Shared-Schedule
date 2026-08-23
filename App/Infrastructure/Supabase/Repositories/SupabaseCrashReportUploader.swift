import _Helpers
import PostgREST
import Auth
import Foundation

final class SupabaseCrashReportUploader: CrashReportUploaderProtocol, @unchecked Sendable {

    func upload(_ report: CrashReport) async throws(CrashReportUploadError) {
        let session: Session
        do {
            session = try await SupabaseClientProvider.auth.session
        } catch {
            throw .notAuthenticated
        }

        // A diagnostic payload should always be valid JSON; fall back to
        // a JSON string so a malformed one still lands for inspection.
        let payload = (try? JSONDecoder().decode(
            AnyJSON.self, from: report.jsonRepresentation
        )) ?? .string(String(decoding: report.jsonRepresentation, as: UTF8.self))

        let dto = CrashReportDTO(
            userId: session.user.id,
            capturedAt: report.timeStampEnd.formatted(.iso8601),
            appVersion: report.appVersion,
            osVersion: report.osVersion,
            payload: payload
        )

        do {
            try await SupabaseClientProvider
                .database(accessToken: session.accessToken)
                .from("crash_reports")
                .insert(dto)
                .execute()
        } catch is URLError {
            throw .network
        } catch {
            throw .persistenceFailure
        }
    }
}
