/// Outcomes for `UserProfile` construction and `UserProfileRepository`
/// operations. Mirrors the pattern set by `BookingError` /
/// `CreateBookingError` (Slice 1.5) — domain invariant + repository
/// outcomes share one enum since the layers' failure modes are tightly
/// related and small.
nonisolated enum UserProfileError: Error, Equatable, Sendable {
    /// `displayName` empty after trim, or longer than 50 chars.
    case invalidDisplayName
    /// Server-side: profile already created for this user (unique_violation).
    case alreadyExists
    /// Fetch path: caller has no profile yet (legacy / partial signup).
    case notFound
    case persistenceFailure
}
