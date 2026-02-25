# Changelog

## Unreleased

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
