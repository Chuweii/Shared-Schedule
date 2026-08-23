// AnyJSON's members live in the SDK's internal `_Helpers` target in
// supabase-swift 2.5.1; MemberImportVisibility requires importing it
// directly (same situation as SupabaseAuthSignUpClient).
import _Helpers
import Foundation

/// PostgREST insert shape for the `crash_reports` table (write-only —
/// there is no SELECT policy, so no decoding counterpart).
struct CrashReportDTO: Encodable, Sendable {
    let userId: UUID
    let capturedAt: String        // ISO 8601 for TIMESTAMPTZ
    let appVersion: String
    let osVersion: String
    let payload: AnyJSON
}
