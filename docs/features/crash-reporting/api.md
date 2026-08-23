# Crash Reporting — Backend 設計

## 資料表

Migration：`supabase/migrations/<ts>_add_crash_reports.sql`

```sql
CREATE TABLE crash_reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  captured_at TIMESTAMPTZ NOT NULL,
  app_version TEXT NOT NULL,
  os_version  TEXT,
  payload     JSONB NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- `payload` = MetricKit `MXCrashDiagnostic.jsonRepresentation()` 原文。
- `captured_at` = 診斷時間區間的結束時間（`timeStampEnd`）。
- 刪帳號 cascade：`user_id` FK `ON DELETE CASCADE`（與既有表一致）。
- Retention：MVP 手動（Studio 跑
  `DELETE FROM crash_reports WHERE created_at < now() - interval '90 days'`；
  註解寫在 migration）。有需要再上 pg_cron。

## RLS

```sql
ALTER TABLE crash_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "self_insert" ON crash_reports
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());
```

- **只有 INSERT**。無 SELECT／UPDATE／DELETE policy：使用者（含本人）
  讀回一律空集合；開發者用 Studio／service role 查看。
- 不開 anon insert（濫用面；anon key 隨 app 散布）。未登入期間的崩潰
  由本機 queue 承接，下次登入後上傳。

## App 端

- 寫入路徑：直接 PostgREST insert（無需 RPC——單表、無跨表 invariant）。
- DTO：`CrashReportDTO { user_id, captured_at, app_version, os_version, payload }`
  於 `App/Infrastructure/Supabase/DTOs/`。
- Uploader：`SupabaseCrashReportUploader`（實作 Domain
  `CrashReportUploaderProtocol`）於
  `App/Infrastructure/Supabase/Repositories/`；`user_id` 取自
  `auth.session.user.id`。
- 觸發：RootView 進入 authenticated 後 fire-and-forget 執行
  `UploadCrashReportsUseCase`。

## Seed

無需 seed data（表由 app 動態寫入；integration 測試用 seed user 登入
後動態 insert）。
