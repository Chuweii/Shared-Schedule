-- Migration: get_bookings_for_owner RPC (Phase 3b Slice 1.5)
--
-- Owner-side equivalent of `fetchAll(scheduleID:, studentID:)`. Returns
-- every booking on the schedule joined with the student's email, so the
-- ScheduleCalendarView owner branch can render "<email> 已預約" rows.
--
-- Why a SECURITY DEFINER RPC and not a direct join:
--   1. PostgREST cannot read auth.users from the public schema (auth
--      schema has tight RLS). RPC running as the function owner bypasses
--      that.
--   2. We want to deny non-owners outright with NOT_OWNER rather than
--      silently returning [].
--
-- Reuses is_owner_of_schedule helper from the Phase 3a migration.
--
-- See docs/features/student-booking/api.md for the contract.

CREATE FUNCTION get_bookings_for_owner(target_schedule_id UUID)
RETURNS TABLE(
  id               UUID,
  schedule_id      UUID,
  student_id       UUID,
  student_email    TEXT,
  starts_at        TIMESTAMPTZ,
  ends_at          TIMESTAMPTZ,
  duration_seconds INTEGER,
  created_at       TIMESTAMPTZ
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF NOT is_owner_of_schedule(target_schedule_id, v_user_id) THEN
    RAISE EXCEPTION 'NOT_OWNER';
  END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.schedule_id,
    b.student_id,
    u.email::TEXT,
    b.starts_at,
    b.ends_at,
    b.duration_seconds,
    b.created_at
  FROM bookings b
  JOIN auth.users u ON u.id = b.student_id
  WHERE b.schedule_id = target_schedule_id
  ORDER BY b.starts_at ASC;
END $$;

GRANT EXECUTE ON FUNCTION get_bookings_for_owner(UUID) TO authenticated;
