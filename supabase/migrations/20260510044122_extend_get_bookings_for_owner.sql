-- Migration: get_bookings_for_owner v2 — JOIN user_profiles for
-- displayName surface (Phase 4 Slice A).
--
-- Adds student_display_name TEXT (nullable when the student hasn't
-- created a profile yet) to the RETURN signature. Postgres requires
-- DROP + CREATE for return-type changes; PostgREST clients silently
-- ignore extra fields so older clients (Slice 1.5 OwnerBookingDTO
-- without studentDisplayName) wouldn't break — but in this codebase
-- the DTO is updated in the same PR.
--
-- LEFT JOIN is intentional: profile-less students still surface their
-- booking row with NULL display_name; client falls back to email.
--
-- See docs/features/user-profile/api.md.

DROP FUNCTION get_bookings_for_owner(UUID);

CREATE FUNCTION get_bookings_for_owner(target_schedule_id UUID)
RETURNS TABLE(
  id                   UUID,
  schedule_id          UUID,
  student_id           UUID,
  student_email        TEXT,
  student_display_name TEXT,
  starts_at            TIMESTAMPTZ,
  ends_at              TIMESTAMPTZ,
  duration_seconds     INTEGER,
  created_at           TIMESTAMPTZ
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
    up.display_name,
    b.starts_at,
    b.ends_at,
    b.duration_seconds,
    b.created_at
  FROM bookings b
  JOIN auth.users u ON u.id = b.student_id
  LEFT JOIN user_profiles up ON up.user_id = b.student_id
  WHERE b.schedule_id = target_schedule_id
  ORDER BY b.starts_at ASC;
END $$;

GRANT EXECUTE ON FUNCTION get_bookings_for_owner(UUID) TO authenticated;
