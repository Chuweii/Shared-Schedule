-- Migration: crash_reports (Phase 4 — App Store readiness)
--
-- Write-only sink for MetricKit crash diagnostics uploaded by the app
-- after sign-in. Users can only INSERT their own rows; there is no
-- SELECT/UPDATE/DELETE policy on purpose — the developer reads via
-- Studio / service role. Pre-auth crashes queue locally on device and
-- upload on the next authenticated launch, so no anon INSERT either
-- (the anon key ships in the binary; an open INSERT is a spam surface).
--
-- Retention is manual for MVP; run in Studio when needed:
--   DELETE FROM crash_reports WHERE created_at < now() - interval '90 days';
--
-- See docs/features/crash-reporting/api.md for the contract.

CREATE TABLE crash_reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  captured_at TIMESTAMPTZ NOT NULL,
  app_version TEXT NOT NULL,
  os_version  TEXT,
  payload     JSONB NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE crash_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self_insert" ON crash_reports
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());
