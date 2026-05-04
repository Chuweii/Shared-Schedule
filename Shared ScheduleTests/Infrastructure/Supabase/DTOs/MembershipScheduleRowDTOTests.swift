import Testing
import Foundation
@testable import Shared_Schedule

struct MembershipScheduleRowDTOTests {

    @Test("PostgREST embedded resource JSON 解出巢狀 schedule + rules + windows")
    func decode_postgrestEmbeddedShape_populatesNestedRulesAndWindows() throws {
        // Given — mimics what `from("memberships").select("schedules!inner(*, availability_rules(*), availability_windows(*))")` returns
        let json = """
        [
          {
            "schedules": {
              "id": "11111111-1111-1111-1111-111111111111",
              "owner_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
              "title": "瑜珈初階",
              "min_window_duration": 3600,
              "created_at": "2026-05-01T00:00:00+00:00",
              "updated_at": "2026-05-01T00:00:00+00:00",
              "availability_rules": [
                {
                  "id": "22222222-2222-2222-2222-222222222222",
                  "schedule_id": "11111111-1111-1111-1111-111111111111",
                  "weekday": 4,
                  "start_time": "09:00:00",
                  "end_time": "18:00:00"
                }
              ],
              "availability_windows": [
                {
                  "id": "33333333-3333-3333-3333-333333333333",
                  "schedule_id": "11111111-1111-1111-1111-111111111111",
                  "start_at": "2026-05-07T09:00:00+00:00",
                  "end_at": "2026-05-07T18:00:00+00:00"
                }
              ]
            }
          }
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // When
        let rows = try decoder.decode([MembershipScheduleRowDTO].self, from: json)

        // Then
        #expect(rows.count == 1)
        let schedule = rows[0].schedules
        #expect(schedule.title == "瑜珈初階")
        #expect(schedule.ownerId == UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"))
        #expect(schedule.availabilityRules?.count == 1)
        #expect(schedule.availabilityRules?.first?.weekday == 4)
        #expect(schedule.availabilityWindows?.count == 1)
        #expect(schedule.availabilityWindows?.first?.startAt == "2026-05-07T09:00:00+00:00")
    }
}
