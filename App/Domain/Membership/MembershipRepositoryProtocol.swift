protocol MembershipRepositoryProtocol: Sendable {
    /// Memberships of all schedules the given user has joined as a student.
    /// Slice 3 uses this to populate the "我加入的" section.
    func fetchAll(for userID: UserID) async throws -> [Membership]
}
