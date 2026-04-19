# Changelog

## [3.1.2] - 2026-04-19

### Fixed
- Auto Discovery: gzip 圧縮レスポンス・chunked 転送エンコーディング・Turbo フォームの3つの問題を修正
  - `Accept-Encoding: identity` を追加して gzip を無効化（`Inflater#closed?` NoMethodError 解消）
  - ストリーミング `break` を廃止し一括受信後に切り詰める方式に変更（chunked クラッシュ解消）
  - フィード候補選択を POST `render` から session + `redirect_to GET /feeds/select` に変更（Turbo 対応）

## [3.1.0] - 2026-04-19

### Added
- ONCE 互換のストレージ設定: `STORAGE_PATH` 環境変数でデータ保存先を切り替え可能に（デフォルト `/storage`）
- `hooks/pre-backup`: バックアップ前に SQLite WAL をチェックポイントして安全にバックアップ
- `hooks/post-restore`: リストア後に `db:migrate` を自動実行

### Changed
- `config/database.yml` / `config/storage.yml`: ストレージパスを `STORAGE_PATH` 環境変数で参照するよう変更
- `config/deploy.yml`: Kamal のボリュームマウント先を `/rails/storage` → `/storage` に変更
- `Dockerfile`: `ENV STORAGE_PATH=/storage`、`VOLUME ["/storage"]` を追加

## [3.0.0] - 2026-04-18

### Changed (Breaking)
- 認証方式をパスワードからマジックリンクに変更。既存ユーザーのパスワードログインは廃止され、メールアドレス入力 → 受信したリンクをクリックしてログインするフローに統一

### Added
- `MagicLink` モデル: トークンを SHA-256 ハッシュ化して保存、15 分有効・使い捨て
- `MagicLinksController#show` でトークン検証とセッション確立
- `MagicLinkMailer` によるログインリンクメール送信
- メール送信サービスに Resend を採用（`gem "resend"`、`config/initializers/resend.rb`）
- セッション作成のレート制限: IP 単位（10 回/3 分）に加え、メールアドレス単位（3 回/10 分）を追加し、メール爆撃を防止
- 本番環境の `APP_HOST` を `config/deploy.yml` に設定し、メーラー URL を `https` 固定に
- `docs/magic_link_auth.md` に実装設計を記載

### Removed
- `has_secure_password` および関連機能（`PasswordsController`、`RegistrationsController` とそれぞれのビュー／テスト）
- シード用環境変数 `TSUBAME_PASSWORD`
- ログイン・新規登録・設定画面のパスワード関連フィールド

### Security
- トークンは DB に SHA-256 ハッシュのみ保存。生トークンはメール送信時のみ使用
- 検証後に `destroy!` でトークン破棄（再利用不可）
- ユーザー列挙対策: 入力メールの存否にかかわらず同一レスポンスを返す

### Database
- `magic_links` テーブル追加（`token_digest` unique index、`expires_at`、`user_id` FK）
- `users.password_digest` を nullable に変更

### Dependencies
- resend 1.3 追加

## [2.3.3] - 2026-04-13

### Fixed
- OPML エクスポート時の `output = ""` を `String.new` に変更し、Ruby 4.x の文字列リテラル凍結化に備える（`bin/rails test` 実行時に `xmldecl.rb:51` で出ていた frozen-string 警告も解消）

### Dependencies
- thruster 0.1.19 → 0.1.20（HTTP→HTTPS リダイレクト前の Host 検証を追加するセキュリティ修正）

## [2.3.2] - 2026-04-13

### Fixed
- Safari でキーボードショートカット `o`（ピン一括オープン）が動かない問題を修正
  - 事前ブランクタブ方式（空URLの `window.open`）が Safari でブロックされるため、ピンURLを `#pin_badge` の data 属性に事前埋め込みする方式に変更
  - ポップアップがブロックされた場合はピン状態を保持（誤って消さない）

### Changed
- `PinnedEntryOpensController#create` を削除（不要になったため）
- `PinnedEntryOpensController#destroy` を JSON から Turbo Stream レスポンスに変更
- `entry_pins/_pin_badge.html.erb` 共通パーシャル化

## [2.3.1] - 2026-04-12

### Changed
- DHH / 37signals コーディング規約の詳細ルールを `.claude/rules/dhh_style.md` に追加
- アーキテクチャ方針を拡充（DB バックエンド優先、concern サイズ目安の具体化）
- エージェントワークフローをローカル設定に分離（プロジェクト規約と個人設定の整理）

## [2.3.0] - 2026-04-11

### Added
- 管理者限定のユーザー管理機能（一覧・作成・編集・削除）
- `Admin` モデルで管理者をレコードとして表現
- 自己削除・自己降格の防止

## [2.2.0] - 2026-04-09

### Added
- エントリ重複排除: 同一URLの記事が複数フィードに存在する場合、一方を既読にすると他のエントリも自動的に既読にする
- `content_url` カラム（正規化URL）を entries テーブルに追加
- URL正規化ルール: utm_*/fbclid/gclid パラメータ除去、フラグメント除去、末尾スラッシュ除去
- 遡及同期用 Rake タスク (`bin/rails entries:sync_duplicate_read_states`)

### Changed
- `mark_feed_entries_as_read!` の `upsert_all` に `update_only` を追加し、ピン状態が上書きされないよう修正

### Fixed
- エントリ切り替え時に詳細ペインのスクロール位置を先頭にリセット

### Dependencies
- Rails 8.1.2.1 → 8.1.3
- Bundler 4.0.9
- solid_queue 1.3.2 → 1.4.0
- kamal 2.10.1 → 2.11.0
- sqlite3 2.9.1 → 2.9.2
- webmock 3.26.1 → 3.26.2

## [2.1.0] - 2026-03-21

### Added
- Display unread count badge on folder headers
- FolderGroup value object for cleaner folder/subscription grouping

### Fixed
- README: correct single-user description to multi-user
- Add docs/backup.md to README documentation list

## [2.0.1] - 2026-03-18

### Fixed
- Fix unread entries disappearing when navigating between feeds with keyboard shortcuts

## [2.0.0] - 2026-03-15

### Added
- Multi-user support: Subscription/UserEntryState models for per-user feed management
- User registration with email/password (minimum 8 characters)
- Logout link in settings dropdown

### Changed
- Feeds and entries are now globally shared; subscriptions link users to feeds (Fastladder-compatible pattern)
- Read/pin state moved from Entry to UserEntryState (per-user)
- Folder, rate, and custom title moved from Feed to Subscription (per-user)
- All controllers scoped through Current.user for data isolation
- OPML import/export scoped to current user's subscriptions
- CleanupEntriesJob uses created_at age and per-user pin state

### Security
- Fix IDOR: entry access restricted to subscribed feeds only
- Fix SQL interpolation in Subscription scope (use sanitize_sql_array)
- Add folder ownership validation on Subscription
- Add cross-user data isolation tests

### Fixed
- Fix j-key advancing past last entry into next feed
- Fix Safari 26+ keyboard shortcuts for opening tabs

## [1.2.1] - 2026-02-25

### Changed
- Move feed/folder management and password change links into a settings dropdown menu

## [1.2.0] - 2026-02-25

### Added
- Folder feature: organize feeds into folders with grouped display on home screen
- Full CRUD for folders with feed assignment on create/edit

## [1.1.0] - 2026-02-23

### Added
- Feed rating (★) feature: rate feeds 0-5 and filter by minimum rate on home screen

### Changed
- Update architecture, feed crawling, and AGENT docs to match current codebase
- Prepare codebase for OSS public release

## 2026-02-17

### Changed
- Refactor FeedsController to 37signals style

### Security
- Require environment variables (`TSUBAME_EMAIL`, `TSUBAME_PASSWORD`) for seed user credentials

## 2026-02-14

### Added
- Password change UI
- Reload button icon in feed list header

### Fixed
- Fix pinned entries being unpinned when popup blocker fires

## 2026-02-12

### Added
- Feed autodiscovery from HTML pages (link tag parsing + URL guessing fallback)
- Dark mode support via CSS custom properties and `prefers-color-scheme`

### Changed
- Refactor Feed::Fetching: streaming HTTP, extract EntryImporter concern
- Extract CLAUDE.md contents into AGENT.md with `@import`

### Security
- Harden SSRF protection and improve OPML import resilience

### Fixed
- Fix mobile viewport height for iOS Safari toolbar (`100dvh`)
- Fix mobile entry nav buttons hidden below viewport

## 2026-02-10

### Added
- Mobile prev/next entry navigation buttons
- SQLite backup scripts for VPS and local Mac
- Mission Control dashboard for Solid Queue
- Japanese locale (`ja.yml`) and default locale setting
- Keyboard shortcut help dialog (`?` key)
- Hatena Bookmark integration (count display, shortcuts, add link)

### Changed
- Split keyboard_controller into focused Stimulus controllers (keyboard, selection, pin, help_dialog)
- Extract Entry::RssParser concern
- Extract non-RESTful entry actions into dedicated controllers
- Move unread count query to Feed model scopes
- Style login page with centered card layout

### Fixed
- Fix click target: feed-item/entry-item are `<a>` tags themselves
- Fix EUC-JP/Shift_JIS feed parsing and add `content:encoded` support

### Security
- Harden OPML import: XML signature check, custom exception, size limit
- Harden IP validation, add RecordNotUnique handling

## 2026-02-06

### Added
- Feed management: create, edit, delete, and manual fetch
- Customizable fetch interval per feed (10min - 24h)
- OPML export feature
- Pinned entries list and open-pinned shortcut (`o` key)
- Mark-all-as-read (`Shift+A`)

### Changed
- Split FeedsController into RESTful controllers
- Refactor FetchFeedJob to delegate to Feed#fetch
- Enable Solid Queue in Puma for production

### Fixed
- Fix unread badge race condition
- Fix unread count showing 1 for feeds with no entries
- Fix pin toggle to use Turbo Stream and update badge in real time
- Fix encoding that stripped Japanese text from feed content

## 2026-02-03

### Added
- 3-pane UI with keyboard shortcuts and Turbo Frames
- Feed crawling with SSRF protection and scheduled jobs
- Feed/Entry models and OPML import
- Single-user authentication with Rails 8 generator
- Kamal deployment configuration for Sakura VPS
- Initial Rails 8.1 project setup
