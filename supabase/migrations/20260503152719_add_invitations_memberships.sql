-- Migration: invitations + memberships
-- Phase 3a: Slice 1 (teacher creates invitation), Slice 2 (student redeems),
-- Slice 3 (member-side RLS on existing tables) all ship together in this
-- single migration so the schema lands once.
--
-- Key design decision: cross-table RLS goes through SECURITY DEFINER
-- helper functions, not EXISTS subqueries. Phase 2's RLS on
-- availability_rules / availability_windows used `EXISTS (SELECT 1 FROM
-- schedules WHERE ...)` — fine when schedules' RLS was non-recursive,
-- but this migration adds `schedules.member_select` which queries
-- memberships, whose policies in turn query schedules. The resulting
-- cycle trips Postgres's "infinite recursion detected in policy"
-- (errcode 42P17). Helpers run as the function owner and bypass RLS,
-- breaking the cycle.
--
-- Object order matters: tables before helper functions, because the
-- helpers reference the tables.
--
-- See docs/features/schedule-invitations/api.md for the full spec.

-- =============================================================
-- 1. Tables (no policies yet)
-- =============================================================

CREATE TABLE invitations (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id  UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  token        TEXT NOT NULL UNIQUE,
  expires_at   TIMESTAMPTZ NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (expires_at > created_at),
  CHECK (length(token) = 8)
);

CREATE INDEX invitations_token_idx ON invitations (token);

CREATE TABLE memberships (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id    UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invitation_id  UUID REFERENCES invitations(id) ON DELETE SET NULL,
  joined_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (schedule_id, user_id)
);

-- =============================================================
-- 2. Helper functions (SECURITY DEFINER bypasses RLS)
-- =============================================================

CREATE FUNCTION is_owner_of_schedule(target_schedule_id UUID, target_user_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER
STABLE
LANGUAGE sql
AS $$
  SELECT EXISTS (SELECT 1 FROM schedules
                 WHERE id = target_schedule_id
                 AND owner_id = target_user_id);
$$;

CREATE FUNCTION is_member_of_schedule(target_schedule_id UUID, target_user_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER
STABLE
LANGUAGE sql
AS $$
  SELECT EXISTS (SELECT 1 FROM memberships
                 WHERE schedule_id = target_schedule_id
                 AND user_id = target_user_id);
$$;

GRANT EXECUTE ON FUNCTION is_owner_of_schedule(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_member_of_schedule(UUID, UUID) TO authenticated;

-- =============================================================
-- 3. RLS on new tables
-- =============================================================

ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner_select" ON invitations
  FOR SELECT USING (is_owner_of_schedule(schedule_id, auth.uid()));

CREATE POLICY "owner_insert" ON invitations
  FOR INSERT WITH CHECK (is_owner_of_schedule(schedule_id, auth.uid()));

ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self_or_owner_select" ON memberships
  FOR SELECT USING (
    user_id = auth.uid()
    OR is_owner_of_schedule(schedule_id, auth.uid())
  );

-- INSERT only via redeem_invitation() RPC — no policy on this table.

-- =============================================================
-- 4. Replace Phase 2's cross-table EXISTS policies with helper-based
--    versions on availability_rules / availability_windows.
--    (schedules' Phase 2 owner_select is `owner_id = auth.uid()`, no
--    cross-reference, no change needed.)
-- =============================================================

DROP POLICY "schedule_owner_select" ON availability_rules;
DROP POLICY "schedule_owner_insert" ON availability_rules;
DROP POLICY "schedule_owner_update" ON availability_rules;
DROP POLICY "schedule_owner_delete" ON availability_rules;

CREATE POLICY "schedule_owner_select" ON availability_rules
  FOR SELECT USING (is_owner_of_schedule(schedule_id, auth.uid()));
CREATE POLICY "schedule_owner_insert" ON availability_rules
  FOR INSERT WITH CHECK (is_owner_of_schedule(schedule_id, auth.uid()));
CREATE POLICY "schedule_owner_update" ON availability_rules
  FOR UPDATE USING (is_owner_of_schedule(schedule_id, auth.uid()))
  WITH CHECK (is_owner_of_schedule(schedule_id, auth.uid()));
CREATE POLICY "schedule_owner_delete" ON availability_rules
  FOR DELETE USING (is_owner_of_schedule(schedule_id, auth.uid()));

DROP POLICY "schedule_owner_select" ON availability_windows;
DROP POLICY "schedule_owner_insert" ON availability_windows;
DROP POLICY "schedule_owner_update" ON availability_windows;
DROP POLICY "schedule_owner_delete" ON availability_windows;

CREATE POLICY "schedule_owner_select" ON availability_windows
  FOR SELECT USING (is_owner_of_schedule(schedule_id, auth.uid()));
CREATE POLICY "schedule_owner_insert" ON availability_windows
  FOR INSERT WITH CHECK (is_owner_of_schedule(schedule_id, auth.uid()));
CREATE POLICY "schedule_owner_update" ON availability_windows
  FOR UPDATE USING (is_owner_of_schedule(schedule_id, auth.uid()))
  WITH CHECK (is_owner_of_schedule(schedule_id, auth.uid()));
CREATE POLICY "schedule_owner_delete" ON availability_windows
  FOR DELETE USING (is_owner_of_schedule(schedule_id, auth.uid()));

-- =============================================================
-- 5. New member_select policies (additive to Phase 2 owner_select).
--    Postgres OR-combines multiple SELECT policies on the same table,
--    so owner-or-member visibility falls out for free.
-- =============================================================

CREATE POLICY "member_select" ON schedules
  FOR SELECT USING (is_member_of_schedule(id, auth.uid()));

CREATE POLICY "member_select" ON availability_rules
  FOR SELECT USING (is_member_of_schedule(schedule_id, auth.uid()));

CREATE POLICY "member_select" ON availability_windows
  FOR SELECT USING (is_member_of_schedule(schedule_id, auth.uid()));

-- =============================================================
-- 6. Atomic redemption RPC
-- =============================================================

CREATE FUNCTION redeem_invitation(invitation_token TEXT)
RETURNS TABLE(schedule_id UUID, membership_id UUID, joined_at TIMESTAMPTZ)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_invitation invitations%ROWTYPE;
  v_user_id UUID := auth.uid();
  v_owner_id UUID;
  v_membership_id UUID;
  v_now TIMESTAMPTZ := now();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT * INTO v_invitation FROM invitations WHERE token = invitation_token;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_TOKEN'; END IF;
  IF v_invitation.expires_at <= v_now THEN RAISE EXCEPTION 'EXPIRED'; END IF;

  SELECT owner_id INTO v_owner_id FROM schedules WHERE id = v_invitation.schedule_id;
  IF v_owner_id = v_user_id THEN RAISE EXCEPTION 'SELF_REDEMPTION'; END IF;

  IF EXISTS (SELECT 1 FROM memberships
             WHERE schedule_id = v_invitation.schedule_id
             AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'ALREADY_MEMBER';
  END IF;

  INSERT INTO memberships (schedule_id, user_id, invitation_id, joined_at)
  VALUES (v_invitation.schedule_id, v_user_id, v_invitation.id, v_now)
  RETURNING id INTO v_membership_id;

  RETURN QUERY SELECT v_invitation.schedule_id, v_membership_id, v_now;
END $$;

GRANT EXECUTE ON FUNCTION redeem_invitation(TEXT) TO authenticated;
