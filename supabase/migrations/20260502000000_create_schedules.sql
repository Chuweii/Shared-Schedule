-- Migration: create core tables for Schedule aggregate
-- Tables: schedules, availability_rules, availability_windows
-- All tables have RLS enabled with owner-based policies.

-- =============================================================
-- 1. schedules
-- =============================================================

CREATE TABLE schedules (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title               TEXT NOT NULL,
  min_window_duration INTEGER NOT NULL DEFAULT 3600,  -- seconds
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON COLUMN schedules.min_window_duration IS 'Minimum booking slot length in seconds';

-- Auto-update updated_at on row change
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON schedules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- RLS
ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner_select" ON schedules
  FOR SELECT USING (owner_id = auth.uid());

CREATE POLICY "owner_insert" ON schedules
  FOR INSERT WITH CHECK (owner_id = auth.uid());

CREATE POLICY "owner_update" ON schedules
  FOR UPDATE USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "owner_delete" ON schedules
  FOR DELETE USING (owner_id = auth.uid());

-- =============================================================
-- 2. availability_rules
-- =============================================================

CREATE TABLE availability_rules (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  weekday     SMALLINT NOT NULL CHECK (weekday BETWEEN 1 AND 7),
  start_time  TIME NOT NULL,
  end_time    TIME NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (schedule_id, weekday)
);

COMMENT ON COLUMN availability_rules.weekday IS '1=Sunday, 2=Monday, ..., 7=Saturday (matches Foundation weekday)';

-- RLS
ALTER TABLE availability_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "schedule_owner_select" ON availability_rules
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM schedules WHERE id = schedule_id AND owner_id = auth.uid())
  );

CREATE POLICY "schedule_owner_insert" ON availability_rules
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM schedules WHERE id = schedule_id AND owner_id = auth.uid())
  );

CREATE POLICY "schedule_owner_update" ON availability_rules
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM schedules WHERE id = schedule_id AND owner_id = auth.uid())
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM schedules WHERE id = schedule_id AND owner_id = auth.uid())
  );

CREATE POLICY "schedule_owner_delete" ON availability_rules
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM schedules WHERE id = schedule_id AND owner_id = auth.uid())
  );

-- =============================================================
-- 3. availability_windows
-- =============================================================

CREATE TABLE availability_windows (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  start_at    TIMESTAMPTZ NOT NULL,
  end_at      TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE availability_windows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "schedule_owner_select" ON availability_windows
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM schedules WHERE id = schedule_id AND owner_id = auth.uid())
  );

CREATE POLICY "schedule_owner_insert" ON availability_windows
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM schedules WHERE id = schedule_id AND owner_id = auth.uid())
  );

CREATE POLICY "schedule_owner_update" ON availability_windows
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM schedules WHERE id = schedule_id AND owner_id = auth.uid())
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM schedules WHERE id = schedule_id AND owner_id = auth.uid())
  );

CREATE POLICY "schedule_owner_delete" ON availability_windows
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM schedules WHERE id = schedule_id AND owner_id = auth.uid())
  );
