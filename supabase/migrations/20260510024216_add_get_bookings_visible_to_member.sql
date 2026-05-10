-- Migration: get_bookings_visible_to_member RPC (Phase 3b Slice 2)
--
-- Cross-student booking visibility: a member of a schedule should be
-- able to see *which time slots* are already booked by other students
-- on that schedule, but never the bookers' identities (no student_id,
-- no email, no booking_id).
--
-- Why a sanitized SECURITY DEFINER RPC and not a relaxed RLS policy:
--   1. OR-adding is_member_of_schedule(...) to the bookings SELECT
--      policy would let `bookings?select=*` return full rows including
--      student_id. PostgREST cannot column-mask. Wrapping with a view
--      adds another layer that has to stay in sync; a single RPC is
--      simpler to audit.
--   2. The base table RLS (self_or_owner_select) stays unchanged, so
--      direct table access can never leak — even by accident from a
--      future ad-hoc query.
--   3. The RETURN TABLE signature is the actual security boundary.
--      Whoever reviews this file only has to verify that signature.
--
-- Reuses is_member_of_schedule helper from the Phase 3a migration.
--
-- See docs/features/student-booking/api.md (Slice 2 section) for the
-- contract.

CREATE FUNCTION get_bookings_visible_to_member(target_schedule_id UUID)
RETURNS TABLE(
  starts_at        TIMESTAMPTZ,
  ends_at          TIMESTAMPTZ,
  duration_seconds INTEGER
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

  IF NOT is_member_of_schedule(target_schedule_id, v_user_id) THEN
    RAISE EXCEPTION 'NOT_MEMBER';
  END IF;

  RETURN QUERY
  SELECT
    b.starts_at,
    b.ends_at,
    b.duration_seconds
  FROM bookings b
  WHERE b.schedule_id = target_schedule_id
    AND b.student_id <> v_user_id
  ORDER BY b.starts_at ASC;
END $$;

GRANT EXECUTE ON FUNCTION get_bookings_visible_to_member(UUID)
  TO authenticated;
