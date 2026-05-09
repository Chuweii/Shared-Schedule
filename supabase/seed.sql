-- Seed data for local development and Studio verification.
-- Creates two test users via Supabase Auth, then inserts sample schedule + rules
-- owned by user A. User B owns nothing — used for RLS deny integration tests.

-- 1a. Create test user A (owns the sample schedule below)
INSERT INTO auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token,
  raw_app_meta_data,
  raw_user_meta_data
) VALUES (
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'test-teacher@example.com',
  crypt('password123', gen_salt('bf')),
  now(),
  now(),
  now(),
  '',
  '',
  '',
  '',
  '{"provider": "email", "providers": ["email"]}',
  '{"display_name": "Test Teacher A"}'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (
  id,
  user_id,
  provider_id,
  provider,
  identity_data,
  last_sign_in_at,
  created_at,
  updated_at
) VALUES (
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'test-teacher@example.com',
  'email',
  '{"sub": "a1b2c3d4-e5f6-7890-abcd-ef1234567890", "email": "test-teacher@example.com"}',
  now(),
  now(),
  now()
) ON CONFLICT (provider_id, provider) DO NOTHING;

-- 1b. Create test user B (owns nothing — used for RLS deny tests)
INSERT INTO auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token,
  raw_app_meta_data,
  raw_user_meta_data
) VALUES (
  'b2c3d4e5-f6a7-8901-bcde-f23456789012',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'test-teacher-b@example.com',
  crypt('password123', gen_salt('bf')),
  now(),
  now(),
  now(),
  '',
  '',
  '',
  '',
  '{"provider": "email", "providers": ["email"]}',
  '{"display_name": "Test Teacher B"}'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (
  id,
  user_id,
  provider_id,
  provider,
  identity_data,
  last_sign_in_at,
  created_at,
  updated_at
) VALUES (
  'b2c3d4e5-f6a7-8901-bcde-f23456789012',
  'b2c3d4e5-f6a7-8901-bcde-f23456789012',
  'test-teacher-b@example.com',
  'email',
  '{"sub": "b2c3d4e5-f6a7-8901-bcde-f23456789012", "email": "test-teacher-b@example.com"}',
  now(),
  now(),
  now()
) ON CONFLICT (provider_id, provider) DO NOTHING;

-- 2. Insert a sample schedule
INSERT INTO schedules (id, owner_id, title, min_window_duration)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'Yoga Beginner',
  3600
);

-- 3. Insert sample availability rules (Mon-Fri, 09:00-18:00)
INSERT INTO availability_rules (schedule_id, weekday, start_time, end_time) VALUES
  ('11111111-1111-1111-1111-111111111111', 2, '09:00', '18:00'),  -- Monday
  ('11111111-1111-1111-1111-111111111111', 3, '09:00', '18:00'),  -- Tuesday
  ('11111111-1111-1111-1111-111111111111', 4, '09:00', '18:00'),  -- Wednesday
  ('11111111-1111-1111-1111-111111111111', 5, '09:00', '18:00'),  -- Thursday
  ('11111111-1111-1111-1111-111111111111', 6, '09:00', '18:00');  -- Friday

-- 4. Insert a sample invitation for the Yoga Beginner schedule.
-- Used in Slice 2 integration tests + manual redemption demos.
INSERT INTO invitations (id, schedule_id, token, expires_at) VALUES (
  '88888888-8888-8888-8888-888888888888',
  '11111111-1111-1111-1111-111111111111',
  'ABCD1234',
  now() + interval '7 days'
) ON CONFLICT (id) DO NOTHING;

-- 5a. Create test user C (a student — already a member of user A's schedule
-- via direct seed below; used by Phase 3b booking integration tests).
-- Keeping this distinct from user B preserves the "user B has no
-- memberships" fixture relied on by Phase 3a JoinedSchedules tests.
INSERT INTO auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token,
  raw_app_meta_data,
  raw_user_meta_data
) VALUES (
  'c3d4e5f6-a7b8-9012-cdef-345678901234',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'test-student-c@example.com',
  crypt('password123', gen_salt('bf')),
  now(),
  now(),
  now(),
  '',
  '',
  '',
  '',
  '{"provider": "email", "providers": ["email"]}',
  '{"display_name": "Test Student C"}'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (
  id,
  user_id,
  provider_id,
  provider,
  identity_data,
  last_sign_in_at,
  created_at,
  updated_at
) VALUES (
  'c3d4e5f6-a7b8-9012-cdef-345678901234',
  'c3d4e5f6-a7b8-9012-cdef-345678901234',
  'test-student-c@example.com',
  'email',
  '{"sub": "c3d4e5f6-a7b8-9012-cdef-345678901234", "email": "test-student-c@example.com"}',
  now(),
  now(),
  now()
) ON CONFLICT (provider_id, provider) DO NOTHING;

-- 5b. User C is a member of user A's Yoga Beginner schedule. invitation_id
-- is NULL because this membership is seeded directly (not via redeem flow).
INSERT INTO memberships (id, schedule_id, user_id, invitation_id) VALUES (
  '99999999-9999-9999-9999-999999999999',
  '11111111-1111-1111-1111-111111111111',
  'c3d4e5f6-a7b8-9012-cdef-345678901234',
  NULL
) ON CONFLICT (id) DO NOTHING;
