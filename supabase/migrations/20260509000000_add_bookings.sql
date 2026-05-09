-- Migration: bookings (Phase 3b Slice 1 — student booking)
--
-- 1-on-1 booking model: a slot is uniquely identified by
-- (schedule_id, starts_at) given the schedule's fixed minWindowDuration.
-- duration_seconds is denormalized so a booking remains semantically
-- intact if the teacher later edits minWindowDuration.
--
-- All mutations go through book_slot / cancel_booking RPCs (SECURITY
-- DEFINER). Direct INSERT/UPDATE/DELETE is blocked by absence of policies.
--
-- Reuses helpers is_owner_of_schedule / is_member_of_schedule defined
-- in the Phase 3a migration (20260503152719_add_invitations_memberships.sql).
--
-- Slice 1 SELECT scope: own booking, OR owner of schedule.
-- Slice 2 (cross-student visibility) will OR-add is_member_of_schedule(...).
--
-- See docs/features/student-booking/api.md for the full spec.

-- =============================================================
-- 1. Table
-- =============================================================

CREATE TABLE bookings (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id       UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  student_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  starts_at         TIMESTAMPTZ NOT NULL,
  ends_at           TIMESTAMPTZ NOT NULL,
  duration_seconds  INTEGER NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at),
  CHECK (duration_seconds > 0),
  UNIQUE (schedule_id, starts_at)
);

CREATE INDEX bookings_schedule_student_idx
  ON bookings (schedule_id, student_id);

-- =============================================================
-- 2. RLS
-- =============================================================

ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self_or_owner_select" ON bookings
  FOR SELECT USING (
    student_id = auth.uid()
    OR is_owner_of_schedule(schedule_id, auth.uid())
  );

-- No INSERT / UPDATE / DELETE policy: all mutations go via RPC.

-- =============================================================
-- 3. book_slot RPC
--
-- Check order is fixed by tests BINT3 / BINT4: auth → range/duration →
-- past → schedule existence → owner → member → INSERT. unique_violation
-- on the INSERT is caught and re-raised as SLOT_TAKEN so the client can
-- map it to .slotTaken without scraping postgres SQLSTATEs.
-- =============================================================

CREATE FUNCTION book_slot(
  target_schedule_id      UUID,
  target_starts_at        TIMESTAMPTZ,
  target_ends_at          TIMESTAMPTZ,
  target_duration_seconds INTEGER
)
RETURNS TABLE(
  id               UUID,
  schedule_id      UUID,
  student_id       UUID,
  starts_at        TIMESTAMPTZ,
  ends_at          TIMESTAMPTZ,
  duration_seconds INTEGER,
  created_at       TIMESTAMPTZ
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_owner_id UUID;
  v_now      TIMESTAMPTZ := now();
  v_id       UUID;
  v_created  TIMESTAMPTZ;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF target_ends_at <= target_starts_at THEN
    RAISE EXCEPTION 'INVALID_RANGE';
  END IF;

  IF target_duration_seconds <= 0 THEN
    RAISE EXCEPTION 'INVALID_DURATION';
  END IF;

  IF target_starts_at <= v_now THEN
    RAISE EXCEPTION 'PAST_SLOT';
  END IF;

  SELECT owner_id INTO v_owner_id
  FROM schedules WHERE schedules.id = target_schedule_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'SCHEDULE_NOT_FOUND';
  END IF;
  IF v_owner_id = v_user_id THEN
    RAISE EXCEPTION 'OWNER_CANNOT_BOOK';
  END IF;

  IF NOT is_member_of_schedule(target_schedule_id, v_user_id) THEN
    RAISE EXCEPTION 'NOT_MEMBER';
  END IF;

  BEGIN
    INSERT INTO bookings (
      schedule_id, student_id, starts_at, ends_at,
      duration_seconds, created_at
    ) VALUES (
      target_schedule_id, v_user_id, target_starts_at, target_ends_at,
      target_duration_seconds, v_now
    )
    RETURNING bookings.id, bookings.created_at
      INTO v_id, v_created;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'SLOT_TAKEN';
  END;

  RETURN QUERY SELECT
    v_id,
    target_schedule_id,
    v_user_id,
    target_starts_at,
    target_ends_at,
    target_duration_seconds,
    v_created;
END $$;

GRANT EXECUTE ON FUNCTION book_slot(UUID, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER)
  TO authenticated;

-- =============================================================
-- 4. cancel_booking RPC
-- =============================================================

CREATE FUNCTION cancel_booking(target_booking_id UUID)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_booking bookings%ROWTYPE;
  v_now     TIMESTAMPTZ := now();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT * INTO v_booking
  FROM bookings WHERE bookings.id = target_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND';
  END IF;

  IF v_booking.student_id <> v_user_id THEN
    RAISE EXCEPTION 'NOT_OWNER';
  END IF;

  IF v_booking.starts_at <= v_now THEN
    RAISE EXCEPTION 'SLOT_STARTED';
  END IF;

  DELETE FROM bookings WHERE bookings.id = target_booking_id;
END $$;

GRANT EXECUTE ON FUNCTION cancel_booking(UUID) TO authenticated;
