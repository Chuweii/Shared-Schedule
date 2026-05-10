-- Migration: user_profiles + create_user_profile RPC (Phase 4 Slice A)
--
-- Stores the human-readable display name shown in owner views and
-- (eventually) any user-discovery surfaces. Direct INSERT is blocked
-- by absent INSERT policy + the create_user_profile RPC is the only
-- path for inserts so server-side length / uniqueness rules stay
-- centralized (matches the book_slot / cancel_booking / redeem_invitation
-- mutation pattern from earlier slices).
--
-- See docs/features/user-profile/api.md for the contract.

-- =============================================================
-- 1. Table
-- =============================================================
CREATE TABLE user_profiles (
  user_id      UUID PRIMARY KEY
               REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL CHECK (
    char_length(display_name) BETWEEN 1 AND 50
  ),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =============================================================
-- 2. RLS — self-only SELECT/UPDATE; no INSERT/DELETE policy
--    (mutations go via SECURITY DEFINER RPC)
-- =============================================================
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self_select" ON user_profiles
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "self_update" ON user_profiles
  FOR UPDATE USING (user_id = auth.uid());

-- =============================================================
-- 3. create_user_profile RPC
-- =============================================================
CREATE FUNCTION create_user_profile(target_display_name TEXT)
RETURNS TABLE(
  user_id      UUID,
  display_name TEXT,
  created_at   TIMESTAMPTZ,
  updated_at   TIMESTAMPTZ
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_trimmed TEXT;
  v_now     TIMESTAMPTZ := now();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  v_trimmed := btrim(target_display_name);
  IF char_length(v_trimmed) < 1 OR char_length(v_trimmed) > 50 THEN
    RAISE EXCEPTION 'INVALID_DISPLAY_NAME';
  END IF;

  BEGIN
    INSERT INTO user_profiles (user_id, display_name, created_at, updated_at)
    VALUES (v_user_id, v_trimmed, v_now, v_now);
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'ALREADY_EXISTS';
  END;

  RETURN QUERY SELECT v_user_id, v_trimmed, v_now, v_now;
END $$;

GRANT EXECUTE ON FUNCTION create_user_profile(TEXT) TO authenticated;
