import Foundation

enum InvitationMapper {

    static func toDomain(_ dto: InvitationDTO) -> Invitation? {
        guard let token = try? InvitationToken(dto.token),
              let expiresAt = ScheduleMapper.parseTimestamptz(dto.expiresAt),
              let createdAtString = dto.createdAt,
              let createdAt = ScheduleMapper.parseTimestamptz(createdAtString)
        else { return nil }

        return try? Invitation(
            id: InvitationID(dto.id),
            scheduleID: ScheduleID(dto.scheduleId),
            token: token,
            expiresAt: expiresAt,
            createdAt: createdAt
        )
    }

    static func toInsertDTO(_ invitation: Invitation) -> InvitationInsertDTO {
        InvitationInsertDTO(
            id: invitation.id.rawValue,
            scheduleId: invitation.scheduleID.rawValue,
            token: invitation.token.rawValue,
            expiresAt: ScheduleMapper.formatTimestamptz(invitation.expiresAt)
        )
    }
}
