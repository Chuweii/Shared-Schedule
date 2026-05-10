import Foundation

/// A `Booking` augmented with the student's email for owner-side display.
///
/// Why a separate VO instead of an optional `studentEmail` on `Booking`:
/// student-side queries deliberately don't surface other students' email
/// (Slice 1 RLS doesn't even let students see other students' booking
/// rows). Keeping the email out of `Booking` keeps that boundary visible
/// in the type system — only the owner-side fetch path produces this.
nonisolated struct OwnerBooking: Sendable, Equatable {
    let booking: Booking
    let studentEmail: String
}
