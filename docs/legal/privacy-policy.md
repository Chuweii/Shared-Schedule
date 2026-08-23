# Shared Schedule 隱私權政策

**生效日期：2026年8月23日**

Shared Schedule（以下稱「本 App」）由 Shared Schedule 開發者（以下稱「我們」）開發與營運。本政策說明我們收集哪些資料、如何使用，以及你對這些資料擁有的權利。

我們的原則很簡單：**只收集提供服務所必需的資料，不追蹤你、不投放廣告、不販售或出租你的任何資料。**

## 1. 我們收集的資料

### 1.1 帳號資料
- **電子郵件地址**：用於註冊、登入、Email 驗證與密碼重設。
- **密碼**：以加密（雜湊）形式儲存於驗證服務中，我們無法讀取你的原始密碼。
- **顯示名稱**：你註冊時填寫的名稱，會顯示給與你共用課表的成員（例如老師檢視預約名單時）。
- **使用者識別碼（User ID）**：系統自動產生的隨機編號，用於關聯你的課表、預約等資料。

### 1.2 使用者內容
- **課表與可預約規則**：你建立的課表名稱、每週可預約時段等設定。
- **預約紀錄**：你在他人課表上建立的預約時段。

### 1.3 崩潰診斷資料
若本 App 發生閃退，我們透過 Apple 的 MetricKit 框架收集崩潰診斷（程式堆疊、App 版本、作業系統版本、發生時間），並在你下次登入時上傳至我們的伺服器，用於修復問題。診斷內容**不包含**你的課表內容、輸入文字或畫面資訊。

### 1.4 僅儲存在你裝置上的資料
外觀主題與語言偏好只儲存在你的裝置上（UserDefaults），不會上傳。

我們**不收集**：位置、通訊錄、照片、廣告識別碼，或任何用於追蹤的資料。

## 2. 資料的使用目的

上述資料僅用於：

1. 提供核心功能（帳號登入、課表建立與分享、預約）
2. 顯示身分（將你的顯示名稱呈現給共用課表的成員）
3. 維護服務品質（依崩潰診斷修復問題）
4. 帳號安全（Email 驗證、密碼重設）

## 3. 其他使用者能看到什麼

- **課表擁有者（老師）**：可看到你在其課表上的預約時段、你的顯示名稱與電子郵件。
- **同一課表的其他學生**：只能看到某時段「已被預約」——**看不到**你的名稱、電子郵件或任何個人資訊。

## 4. 資料分享與委託處理

我們不販售、出租或交換你的個人資料。資料儲存於 **Supabase**（我們的後端服務供應商）之基礎設施，Supabase 僅依我們的指示處理資料。除以下情形外，我們不會向任何第三方揭露你的資料：

- 依法律、法院命令或主管機關之合法要求
- 為保護使用者或公眾之重大安全所必要

本 App 不包含任何第三方廣告或分析 SDK。

## 5. 資料保存與刪除

- **帳號資料與使用者內容**：保存至你刪除帳號為止。你可以隨時在 App 內「設定 → 刪除帳號」**即時、永久**刪除帳號——所有課表、預約、個人資料與相關紀錄會一併自資料庫刪除，無需透過客服。
- **崩潰診斷**：保存期限最長 90 天，逾期刪除。
- **裝置端偏好**：解除安裝 App 即清除。

## 6. 資料安全

所有資料透過加密連線（HTTPS/TLS）傳輸；資料庫存取受列級安全性（Row Level Security）保護，確保每位使用者只能存取自己有權限的資料。

## 7. 兒童隱私

本 App 不以未滿 13 歲兒童為對象。若我們發現在未經法定代理人同意下收集了兒童的個人資料，將儘速刪除。

## 8. 你的權利

依個人資料保護相關法令，你可以查詢、閱覽、更正或刪除你的個人資料。顯示名稱可直接在 App 內「設定」修改；刪除帳號可在 App 內完成；其他請求請來信聯絡我們。

## 9. 政策變更

本政策若有重大變更，我們會更新本頁面並調整生效日期。持續使用本 App 即表示你同意變更後的政策。

## 10. 聯絡我們

如有任何隱私相關問題，請來信：**kyoii377@gmail.com**

---

# Shared Schedule Privacy Policy (English)

**Effective date: August 23, 2026**

Shared Schedule (the "App") is developed and operated by the Shared Schedule developer ("we", "us"). This policy explains what data we collect, how we use it, and your rights over it.

Our principle is simple: **we collect only what the service needs, and we do not track you, serve ads, or sell or rent any of your data.**

## 1. Data We Collect

### 1.1 Account data
- **Email address** — for sign-up, sign-in, email verification, and password reset.
- **Password** — stored in hashed form by the authentication service; we cannot read your original password.
- **Display name** — the name you enter at sign-up, shown to members who share a schedule with you (e.g., a teacher viewing bookings).
- **User ID** — a randomly generated identifier that links your schedules and bookings.

### 1.2 User content
- **Schedules and availability rules** — schedule titles and weekly availability settings you create.
- **Bookings** — the time slots you book on others' schedules.

### 1.3 Crash diagnostics
If the App crashes, we collect crash diagnostics (stack trace, app version, OS version, timestamp) via Apple's MetricKit framework and upload them on your next signed-in launch to fix the problem. Diagnostics do **not** include your schedule content, typed text, or screen contents.

### 1.4 Data stored only on your device
Theme and language preferences are stored only on your device (UserDefaults) and are never uploaded.

We do **not** collect: location, contacts, photos, advertising identifiers, or any data used for tracking.

## 2. How We Use Data

Solely to: (1) provide core features (sign-in, schedule creation and sharing, booking); (2) display your identity to schedule members; (3) maintain service quality using crash diagnostics; (4) secure your account (email verification, password reset).

## 3. What Other Users Can See

- **Schedule owners (teachers)** can see your booked slots, display name, and email.
- **Other students on the same schedule** only see that a slot is "booked" — never your name, email, or any personal information.

## 4. Sharing and Processing

We do not sell, rent, or trade your personal data. Data is stored on **Supabase** infrastructure (our backend provider), which processes data only on our instructions. We disclose data to no other third party except as required by law or to protect the vital safety of users or the public. The App contains no third-party advertising or analytics SDKs.

## 5. Retention and Deletion

- **Account data and user content** — kept until you delete your account. You can permanently delete your account at any time in-app via Settings → Delete Account; all schedules, bookings, profile data, and related records are removed from the database immediately, no support ticket needed.
- **Crash diagnostics** — kept at most 90 days.
- **On-device preferences** — removed when you uninstall the App.

## 6. Security

All data is transmitted over encrypted connections (HTTPS/TLS). Database access is protected by Row Level Security, ensuring each user can only access data they are entitled to.

## 7. Children's Privacy

The App is not directed at children under 13. If we learn we have collected a child's personal data without parental consent, we will delete it promptly.

## 8. Your Rights

You may access, review, correct, or delete your personal data. Display names can be edited in-app; account deletion is available in-app; for other requests, contact us by email.

## 9. Changes

If this policy changes materially, we will update this page and the effective date. Continued use of the App constitutes acceptance.

## 10. Contact

For privacy questions, email **kyoii377@gmail.com**.
