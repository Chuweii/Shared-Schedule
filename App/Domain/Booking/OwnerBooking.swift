import Foundation

/// A `Booking` augmented with the student's owner-side identity (email
/// always; displayName when the student has a `user_profiles` row).
///
/// Why a separate VO instead of attaching to `Booking`: student-side
/// queries deliberately don't surface other students' email
/// (Slice 1 RLS doesn't even let students see other students' booking
/// rows). Keeping these fields out of `Booking` keeps that boundary
/// visible in the type system — only the owner-side fetch path
/// produces this.
///
/// `studentDisplayName` is `nil` when the student hasn't completed the
/// Phase 4 Slice A signup flow (legacy users, or freshly signed-up users
/// whose `create_user_profile` RPC hasn't landed yet). View layer falls
/// back to `studentEmail` in that case.
nonisolated struct OwnerBooking: Sendable, Equatable {
    let booking: Booking
    let studentEmail: String
    let studentDisplayName: String?

    init(
        booking: Booking,
        studentEmail: String,
        studentDisplayName: String? = nil
    ) {
        self.booking = booking
        self.studentEmail = studentEmail
        self.studentDisplayName = studentDisplayName
    }
}
