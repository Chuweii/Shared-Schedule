-- Fix `column reference "schedule_id" is ambiguous` from the original
-- `redeem_invitation` function. The OUT parameters declared via
-- RETURNS TABLE(schedule_id, membership_id, joined_at) introduced
-- PL/pgSQL variables that collide with the table columns of the same
-- name inside the function body. Slice 1 didn't exercise the success
-- path so the bug stayed dormant; Slice 2 surfaced it via integration
-- tests of the actual redeem flow.
--
-- Fix: alias every queried table and qualify each column reference so
-- PG never has to choose between an OUT parameter and a column.

CREATE OR REPLACE FUNCTION redeem_invitation(invitation_token TEXT)
RETURNS TABLE(schedule_id UUID, membership_id UUID, joined_at TIMESTAMPTZ)
SECURITY DEFINER LANGUAGE plpgsql AS $$
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

  SELECT * INTO v_invitation
  FROM invitations
  WHERE invitations.token = invitation_token;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_TOKEN'; END IF;
  IF v_invitation.expires_at <= v_now THEN RAISE EXCEPTION 'EXPIRED'; END IF;

  SELECT s.owner_id INTO v_owner_id
  FROM schedules s
  WHERE s.id = v_invitation.schedule_id;
  IF v_owner_id = v_user_id THEN RAISE EXCEPTION 'SELF_REDEMPTION'; END IF;

  IF EXISTS (
    SELECT 1 FROM memberships m
    WHERE m.schedule_id = v_invitation.schedule_id
      AND m.user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'ALREADY_MEMBER';
  END IF;

  INSERT INTO memberships (schedule_id, user_id, invitation_id, joined_at)
  VALUES (v_invitation.schedule_id, v_user_id, v_invitation.id, v_now)
  RETURNING memberships.id INTO v_membership_id;

  RETURN QUERY SELECT v_invitation.schedule_id, v_membership_id, v_now;
END $$;
