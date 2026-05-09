import PostgREST
import Auth
import Foundation

final class SupabaseBookingRepository: BookingRepositoryProtocol, @unchecked Sendable {

    private struct BookSlotParams: Encodable, Sendable {
        let targetScheduleId: UUID
        let targetStartsAt: String
        let targetEndsAt: String
        let targetDurationSeconds: Int
    }

    private struct CancelBookingParams: Encodable, Sendable {
        let targetBookingId: UUID
    }

    private func db() async throws -> PostgrestClient {
        let session = try await SupabaseClientProvider.auth.session
        return SupabaseClientProvider.database(accessToken: session.accessToken)
    }

    func create(
        scheduleID: ScheduleID,
        startsAt: Date,
        endsAt: Date,
        durationSeconds: Int
    ) async throws(CreateBookingError) -> Booking {
        let params = BookSlotParams(
            targetScheduleId: scheduleID.rawValue,
            targetStartsAt: ScheduleMapper.formatTimestamptz(startsAt),
            targetEndsAt: ScheduleMapper.formatTimestamptz(endsAt),
            targetDurationSeconds: durationSeconds
        )

        let dtos: [BookingDTO]
        do {
            dtos = try await db()
                .rpc("book_slot", params: params)
                .execute()
                .value
        } catch let pg as PostgrestError {
            throw BookingMapper.mapBookError(pg)
        } catch {
            throw .persistenceFailure
        }

        guard let dto = dtos.first,
              let booking = BookingMapper.toDomain(dto)
        else {
            throw .persistenceFailure
        }
        return booking
    }

    func cancel(id: BookingID) async throws(CancelBookingError) {
        let params = CancelBookingParams(targetBookingId: id.rawValue)

        do {
            try await db()
                .rpc("cancel_booking", params: params)
                .execute()
        } catch let pg as PostgrestError {
            throw BookingMapper.mapCancelError(pg)
        } catch {
            throw .persistenceFailure
        }
    }

    func fetchAll(
        scheduleID: ScheduleID,
        studentID: UserID
    ) async throws -> [Booking] {
        let dtos: [BookingDTO] = try await db()
            .from("bookings")
            .select()
            .eq("schedule_id", value: scheduleID.rawValue)
            .eq("student_id", value: studentID.rawValue)
            .order("starts_at", ascending: true)
            .execute()
            .value
        return dtos.compactMap(BookingMapper.toDomain)
    }
}
