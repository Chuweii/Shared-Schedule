# 語言設定 — Scenarios

> 完整 BDD scenario list（Given / When / Then）。每筆 scenario title 對應
> 一個 `@Test` function；test 名以 camelCase 對映（testing.md §2）。
> 代碼前綴：LO = LanguageOption、LM = LanguageManager、
> LUI = Language UI（手動 e2e，不寫自動化 view test）。

## LanguageOption（3）

### LO1 rawValue 為穩定儲存格式
**Given** 四個 LanguageOption case
**When** 讀取 rawValue
**Then** 依序為 `"system"` / `"zh-Hant"` / `"en"` / `"ja"`（此為
UserDefaults 持久化格式，不可變動）

### LO2 跟隨系統不覆寫 locale
**Given** `.system`
**When** 讀取 overrideLocale
**Then** 為 `nil`

### LO3 語言選項對應正確 locale
**Given** `.traditionalChinese` / `.english` / `.japanese`
**When** 讀取 overrideLocale
**Then** 分別為 `Locale(identifier: "zh-Hant")` / `"en"` / `"ja"`

## LanguageManager（6）

> 測試用 `UserDefaults(suiteName: "test.language.<UUID>")` 隔離，
> 測後 `removePersistentDomain` 清除。

### LM1 從未選過 → 預設跟隨系統
**Given** 空的 UserDefaults（使用者從未手動選過語言）
**When** LanguageManager 初始化
**Then** current == `.system`；overrideLocale == nil（App 顯示系統語言）

### LM2 已存選擇 → 啟動時還原
**Given** UserDefaults 已存 `"ja"`
**When** LanguageManager 初始化
**Then** current == `.japanese`

### LM3 儲存值毀損 → 安全回退跟隨系統
**Given** UserDefaults 存了不合法的值（如 `"klingon"`）
**When** LanguageManager 初始化
**Then** current == `.system`（不閃退、不殘留壞值行為）

### LM4 選擇語言 → 更新並持久化
**Given** 初始為 `.system`
**When** select(`.english`)
**Then** current == `.english`；UserDefaults 值 == `"en"`

### LM5 重複選同一語言 → no-op
**Given** current 已是 `.english`
**When** select(`.english`)
**Then** current 不變（無多餘寫入行為）

### LM6 重啟 App → 選擇保留
**Given** 前一個 LanguageManager 已 select(`.english`)
**When** 用同一 UserDefaults suite 建立新的 LanguageManager（模擬重啟）
**Then** current == `.english`

## Language UI（手動 e2e，4）

> 依現行慣例 SwiftUI view 不寫自動化測試，以模擬器手動驗收。

### LUI1 切換到 English 立即生效
**Given** 使用者在 設定 →「語言」，目前為跟隨系統（裝置為繁中）
**When** 點選 English
**Then** 該列出現 ✓；導覽標題「設定」→ "Settings"，關閉 sheet 後課表
列表、行事曆、各按鈕皆為英文；全程不需重啟

### LUI2 切換到 日本語 立即生效
**Given** 承上，目前為 English
**When** 點選 日本語
**Then** 介面立即變日文

### LUI3 切回繁體中文
**Given** 承上，目前為 日本語
**When** 點選 繁體中文
**Then** 介面立即變繁中

### LUI4 跟隨系統
**Given** 目前為 English，裝置系統語言為繁中
**When** 點選 跟隨系統
**Then** 介面立即回到繁中；殺掉 App 重開仍為繁中

## 一致性驗收（隨 Slice 2，手動 e2e）

- 語言為 English 時：登入驗證錯誤、顯示名稱儲存錯誤、預約確認 alert、
  行事曆月份標題、星期符號 → 全為英文。

## Test 數量

| 層 | 數量 |
|---|---|
| LanguageOption (LO) | 3 |
| LanguageManager (LM) | 6 |
| UI（手動 LUI + 一致性） | 手動 |
| **自動化合計** | **9** |
