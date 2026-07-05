import Foundation

protocol AccountRepositoryProtocol: Sendable {
    /// Permanently delete the caller's account via the `delete_account`
    /// SECURITY DEFINER RPC. All owned data (schedules / memberships /
    /// bookings / user_profiles) cascades via `ON DELETE CASCADE` FKs.
    /// The caller's session is invalidated server-side as a side effect.
    func deleteAccount() async throws(DeleteAccountError)
}
