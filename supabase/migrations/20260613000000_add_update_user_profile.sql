-- Migration: update_user_profile RPC (Phase 4 Slice B)
--
-- Upserts the caller's display_name for the settings-edit path.
-- Complements create_user_profile (signup path): legacy / partial-signup
-- users with no row get one created (upsert), so a single RPC handles
-- both "first time setting a name in settings" and "renaming". Length
-- validated server-side, mirroring create_user_profile.
--
-- No table / RLS / seed change — only this RPC.
--
-- See docs/features/account-settings/api.md for the contract.

CREATE FUNCTION update_user_profile(target_display_name TEXT)
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

  -- Explicit UPDATE-then-INSERT upsert. `ON CONFLICT (user_id)` would be
  -- ambiguous here: RETURNS TABLE declares a `user_id` OUT variable that
  -- collides with the column, and ON CONFLICT's target can't be
  -- qualified. Qualifying the column in UPDATE/WHERE avoids that.
  UPDATE user_profiles
     SET display_name = v_trimmed,
         updated_at   = v_now
   WHERE user_profiles.user_id = v_user_id;

  IF NOT FOUND THEN
    INSERT INTO user_profiles (user_id, display_name, created_at, updated_at)
    VALUES (v_user_id, v_trimmed, v_now, v_now);
  END IF;

  RETURN QUERY
  SELECT up.user_id, up.display_name, up.created_at, up.updated_at
  FROM user_profiles up
  WHERE up.user_id = v_user_id;
END $$;

GRANT EXECUTE ON FUNCTION update_user_profile(TEXT) TO authenticated;
