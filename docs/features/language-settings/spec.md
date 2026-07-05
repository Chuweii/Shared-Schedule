# 語言設定 — Spec

> 使用者在 Settings 內即時切換 App 顯示語言
> （跟隨系統／繁體中文／English／日本語）

## Why

App 的 String Catalog 已備妥 zh-Hant / en / ja 三種語言，且三個 `.lproj`
都已編譯進 bundle，但**完全沒有切換機制**——App 只能跟隨系統語言。
目標市場（台灣的獨立教師與其學生，含日語 / 英語使用者）常見「裝置語言
與偏好閱讀語言不同」的情境，需要 App 內語言選項。

## What

### 新增的概念

- **`LanguageOption`**（Presentation enum）：`system` / `zh-Hant` / `en` /
  `ja` 四個選項；rawValue 即持久化格式與 locale identifier。
- **`LanguageManager`**（`@Observable`）：目前選擇 + `UserDefaults` 持久化
  （key `app.language.selected`），與 `ThemeManager` 同型態。
- **`LanguageSettingsView`**：Settings 內新的「語言」區塊，checkmark
  列選單（與主題選單同樣式）。
- **App root locale 覆寫**：`Shared_ScheduleApp` 依選擇套用
  `.environment(\.locale, ...)`，全 App 立即重新解析字串。

### 使用者可以做的事（增量）

- 進入 Settings（齒輪）→「語言」區塊，看到目前選擇（預設「跟隨系統」）。
- 點選 繁體中文 / English / 日本語 → **整個 App 立即**切換為該語言，
  不需重啟。
- 點選「跟隨系統」→ 回到裝置系統語言。
- 選擇跨啟動保留（含登入畫面）。

### Domain modeling

純 Presentation 層的裝置本地偏好（與主題切換同類）：無 aggregate、無
invariant、無 Usecase、無後端資料。

## 不做的事（Out of Scope）

- **語言偏好雲端同步**：偏好只存本機 `UserDefaults`。
- **登入前切換語言**：切換器在 Settings（登入後）；登入頁會套用上次
  儲存的選擇，但全新使用者首次登入前只能用系統語言。
- **`ThemeSettingsView` 既有英文字串**（Theme / Preview / Primary Text…）
  與 `ThemeOption.displayName` 的翻譯 → 既有缺口，另開任務。
- **系統元件語言**：鍵盤、系統分享面板、日期滾輪內部等由 iOS 控制，
  仍跟隨系統語言（`\.locale` 覆寫的固有限制）。

## Permissions

裝置本地偏好，無權限議題；任何使用狀態（含未登入啟動時讀取偏好）皆可。

## User Flow

```
ScheduleListView 齒輪 → Settings sheet → SettingsView
  ↓ 捲到「語言」區塊（帳號、外觀之後）
LanguageSettingsView：跟隨系統 ✓ / 繁體中文 / English / 日本語
  ↓ 點選 English
LanguageManager.select(.english)
  → UserDefaults 寫入 "en"
  → Shared_ScheduleApp 重算 .environment(\.locale, Locale("en"))
  → 全 App Text(LocalizedStringKey) 立即以 en 重新解析
```

## Scenarios 摘要

完整 Given / When / Then 見 [scenarios.md](scenarios.md)。

| 代碼 | 情境 | 層 |
|---|---|---|
| LO1–LO3 | LanguageOption rawValue / overrideLocale 對應 | Option enum |
| LM1–LM6 | 預設跟隨系統、還原、毀損回退、選擇持久化、同值 no-op、重啟還原 | Manager |
| LUI1–LUI4 | 即時切換 en / ja / zh-Hant、跟隨系統（手動 e2e） | View |

## Technical Notes

- **即時生效機制**：root 的 `.environment(\.locale, override ?? .current)`。
  `Text(LocalizedStringKey)`（含中文字面值 key）會跟隨環境 locale 重新查
  catalog；`String(localized:)` **不會**——因此登入 / 設定錯誤訊息改為
  「VM 暴露 error enum、View 對應 `LocalizedStringKey`」模式（同
  `CreateScheduleSheet.errorMessage(for:)`），日期改用 `Text(_, format:)`。
- **跟隨系統**：`.system` 時 override 為 `nil`，套 `Locale.current`；系統
  語言變更時 iOS 會自動重啟 App，不會殘留過期 locale。
- **導覽列標題**：`navigationTitle(LocalizedStringKey)` 只在「值改變」時
  重推給導覽列——locale 換了但 key 相同 → 不更新，切換當下停留在畫面上
  的標題會殘留舊語言。解法：這類標題（課表列表、Settings sheet）改用
  `String(localized:bundle: .forLocale(locale))` 解析，讓值本身隨語言
  改變（`Bundle+LanguageOverride.swift`，測試 BFL1–BFL4）。
- **`knownRegions`**：pbxproj 補宣告 `zh-Hant` / `ja`（影響 App Store
  語言列表與 iOS「單一 App 語言」設定；App 內切換本身不依賴它）。
- **已知風險**：`Text(LocalizedStringResource)` 型的行內錯誤（課表列表、
  邀請等）是否跟隨 `\.locale` 即時切換需實測；若否，後續套同樣 enum 模式。
