-- Migration: delete_account RPC (Phase 4 Slice B)
--
-- Permanently deletes the caller's auth.users row. All app data cascades
-- via existing ON DELETE CASCADE FKs:
--   schedules.owner_id / memberships.user_id / bookings.student_id /
--   user_profiles.user_id  → all reference auth.users(id) ON DELETE CASCADE.
-- The auth schema's own sessions / refresh_tokens / identities cascade
-- too, so the session is invalidated server-side.
--
-- Runs as postgres (SECURITY DEFINER, owned by the migration role) so it
-- has DELETE privilege on auth.users — the standard Supabase
-- self-service account-deletion pattern, avoiding an Edge Function.
--
-- See docs/features/account-settings/api.md (incl. the Edge Function
-- fallback if this RPC path is ever rejected).

CREATE FUNCTION delete_account()
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  DELETE FROM auth.users WHERE id = v_user_id;
END $$;

GRANT EXECUTE ON FUNCTION delete_account() TO authenticated;
