-- Seed data for local development and Studio verification.
-- Creates a test user via Supabase Auth, then inserts sample schedule + rules.

-- 1. Create a test user in auth.users
-- Using supabase_auth_admin role to insert directly into auth schema.
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
  '{"provider": "email", "providers": ["email"]}',
  '{"display_name": "Test Teacher"}'
) ON CONFLICT (id) DO NOTHING;

-- Also insert into auth.identities (required for auth to work)
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
