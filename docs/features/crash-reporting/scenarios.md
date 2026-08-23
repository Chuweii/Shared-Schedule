# Crash Reporting — Scenarios

> 測試函式名與情境標題互相對映（可雙向 grep）。
> MetricKit boundary glue（subscriber、bootstrap）為不可測層，不在此列。

---

## Domain — CrashReport（CRD）

### CRD1 檔名含結束時間與識別碼
- **Given** 一筆 `CrashReport`（固定 id 與時間區間）
- **When** 取得 `fileName()`
- **Then** 檔名包含 ISO8601 結束時間與 id，且以 `crash-` 開頭、`.json` 結尾

`fileName_containsTimestampAndID`

### CRD2 相同 payload 產生相同內容雜湊
- **Given** 兩筆 `jsonRepresentation` 相同、id 不同的 `CrashReport`
- **When** 比較 `contentHash`
- **Then** 兩者相等；payload 不同時不相等

`contentHash_identicalPayloads_areEqual`

---

## Infrastructure — FileCrashReportStore（FCS）

### FCS1 空儲存庫寫入一筆後可列出
- **Given** 指向空暫存目錄的 store
- **When** 儲存一筆報告
- **Then** `listAll()` 回傳該筆，且目錄中存在對應 JSON 檔

`save_emptyStore_persistsFile`

### FCS2 相同 payload 重複寫入只留一筆
- **Given** 已存有一筆報告的 store
- **When** 儲存 payload 相同（id 不同）的另一筆
- **Then** `listAll()` 仍只有一筆、目錄只有一個檔案

`save_duplicatePayload_isDeduped`

### FCS3 超過保留上限時修剪最舊
- **Given** 已存滿 20 筆（時間遞增）的 store
- **When** 儲存第 21 筆
- **Then** 最舊一筆被刪除，總數維持 20 且最新一筆存在

`save_beyondRetentionLimit_prunesOldest`

### FCS4 目錄中的壞檔被跳過
- **Given** 目錄中有一個非 CrashReport JSON 的檔案與一筆正常報告
- **When** `listAll()`
- **Then** 回傳正常報告、不拋錯

`listAll_corruptFile_isSkipped`

### FCS5 檔名非 canonical 的報告仍可刪除
- **Given** 目錄中有一筆內容正常、但檔名非 `fileName()` 推導名的報告
  （防「刪不掉→每次啟動重複上傳」）
- **When** `delete(id:)`
- **Then** 該檔被刪除、`listAll()` 為空

`delete_nonCanonicalFileName_stillRemovesFile`

---

## Usecase — RecordCrashReportsUseCase（RCU）

### RCU1 多筆報告全數儲存
- **Given** fake store 與兩筆新報告
- **When** 記錄
- **Then** 兩筆皆被儲存

`recordCrashReports_twoReports_bothSaved`

### RCU2 儲存失敗不向外拋錯
- **Given** 儲存必定失敗的 fake store
- **When** 記錄
- **Then** 不拋錯（best-effort，僅記 log）

`recordCrashReports_storeFailure_doesNotThrow`

---

## Usecase — UploadCrashReportsUseCase（UCU）

### UCU1 上傳成功後刪除本機檔案
- **Given** fake store 有兩筆報告、fake uploader 全部成功
- **When** 執行上傳
- **Then** 兩筆皆上傳且 store 中已刪除

`uploadPendingReports_success_deletesLocal`

### UCU2 上傳失敗保留本機檔案
- **Given** fake store 有兩筆報告、fake uploader 第二筆失敗
- **When** 執行上傳
- **Then** 第一筆已刪除、第二筆保留且不拋錯

`uploadPendingReports_partialFailure_keepsFailed`

### UCU3 空 queue 不呼叫 uploader
- **Given** fake store 為空
- **When** 執行上傳
- **Then** uploader 未被呼叫

`uploadPendingReports_emptyQueue_uploaderNotCalled`

---

## Integration — Supabase RLS（CRINT）

> 依慣例：`-parallel-testing-enabled NO`；`db reset` 後等 5–10 秒。

### CRINT1 已登入使用者可寫入自己的崩潰報告
- **Given** 已登入的 seed user
- **When** 以自己的 user_id insert 一筆 `crash_reports`
- **Then** insert 成功（不拋錯）

`insertCrashReport_authenticatedSelf_succeeds`

### CRINT2 使用者讀不回崩潰報告
- **Given** 已登入且剛 insert 過一筆的 seed user
- **When** select `crash_reports`
- **Then** 回傳空集合（無 SELECT policy）

`selectCrashReports_authenticated_returnsEmpty`
