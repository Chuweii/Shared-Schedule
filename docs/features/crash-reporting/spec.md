# Crash Reporting（MetricKit 崩潰回報）

## Why

App Store 上架後，未加入 crash reporting 前開發者只能看到「有同意分享分析」
使用者的 Xcode Organizer 報告，涵蓋率低。本功能用 Apple 原生 MetricKit
收集崩潰診斷（不需使用者另行同意分析分享、不加第三方 SDK），先落地本機、
待使用者登入後上傳 Supabase，讓開發者在 Studio 就能看到 production 崩潰。

## What

- App 啟動時向 MetricKit 註冊訂閱者；OS 在「下一次啟動」時交付前次
  崩潰的診斷 payload。
- 收到 payload 後立即轉成自有的 `CrashReport` 值型別，存入 app 的
  Application Support 目錄（JSON 檔、內容雜湊去重、最多保留 20 筆）。
- 使用者以已登入狀態啟動（或登入成功）後，將本機累積的報告上傳到
  Supabase `crash_reports` 表，上傳成功才刪除本機檔案。
- 全程 best-effort：儲存或上傳失敗只記 log，永不影響 app 功能。

## User Flow

使用者無感。唯一的資料面影響：崩潰診斷（堆疊、app 版本、OS 版本、
發生時間）會連同使用者 ID 上傳 —— 已同步申報於 PrivacyInfo.xcprivacy
（Crash Data／Linked／非 tracking），並將載明於 Privacy Policy。

## Permissions

- 上傳需已登入（RLS `self_insert`：`user_id = auth.uid()`）。
- 未登入期間的崩潰先留在本機 queue，待下次登入後上傳。
- 使用者（含本人）無法讀取／修改／刪除 `crash_reports`（無 SELECT／
  UPDATE／DELETE policy）；開發者透過 Studio／service role 查看。
- 刪除帳號時 `ON DELETE CASCADE` 一併清除該使用者的崩潰報告。

## Scenarios 摘要

完整 Given/When/Then 見 [scenarios.md](scenarios.md)。

| 代號 | 情境 | 層 |
|---|---|---|
| CRD1–2 | CrashReport 檔名／內容雜湊 | Domain |
| FCS1–5 | 本機儲存：寫檔、去重、保留上限、壞檔容忍、非 canonical 檔名可刪 | Infrastructure |
| RCU1–2 | 記錄 usecase：全數落地、失敗不拋 | Usecase |
| UCU1–3 | 上傳 usecase：成功即刪、失敗保留、空 queue 不動作 | Usecase |
| CRINT1–2 | RLS：本人可 insert、讀回為空 | Integration |

## Technical Notes

- `MXDiagnosticPayload`／`MXCrashDiagnostic` 無 public initializer，
  **無法在測試中建構** → 在 boundary（`MetricKitCrashSubscriber`）立即
  轉成 `CrashReport`，subscriber 本身為 <40 行不測 glue；下游全部 TDD
  （fixture = 測試檔內嵌 JSON 字串）。
- 專案預設 MainActor；`didReceive(_:)` 由 MetricKit 背景 queue 呼叫，
  subscriber 宣告 `nonisolated`，同步轉換後以 `Task` 跳回 usecase。
- 診斷交付時機由 OS 決定（下次啟動、可能延遲至 24h），無法即時；
  開發驗證用 Xcode「Simulate MetricKit Payloads」。
- 唯一 `import MetricKit` 位於 `App/Infrastructure/Diagnostics/
  MetricKitCrashSubscriber.swift`（比照 Supabase 包裝規則）。
