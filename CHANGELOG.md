# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `bin/rails generate` (and other commands that load `lib/solid_queue_web/engine` directly) no longer fail with `uninitialized constant Rails::Engine` — the engine now requires `rails`, `active_model/railtie`, `active_job/railtie`, and `active_record/railtie` before `solid_queue`

## [1.6.0] - 2026-06-08

### Added

- i18n support
- Custom dashboard cards — `config.dashboard_cards` accepts an array of `{ title:, stats:, link: }` hashes; each card is rendered after the built-in queue stat cards on the dashboard; `stats:` is a lambda returning a `{ label => value }` hash evaluated at render time; `link:` is an optional `{ label:, url: }` header link
- Custom nav links — `config.nav_links` accepts an array of `{ label:, url: }` hashes appended to the main navigation bar after the built-in links

### Changed

- README restructured with a Table of Contents, section dividers, and "Back to top" links; alert sections consolidated under a single `## Webhook alerts` parent — all UI strings are now extracted into `config/locales/en.yml`; locale switching via `?locale=` param or session is supported; host apps can add additional locales using `SolidQueueWeb.available_locales = %i[en es]`; the English locale file can be used as a template for translations

## [1.5.0] - 2026-05-28

### Added

- Admin audit log — every discard, retry, pause, and resume action is recorded to a `solid_queue_web_audit_events` table; viewable at `/jobs/audit` with action/actor/queue filters and CSV export; identity captured via the optional `SolidQueueWeb.current_actor` config block; table created via `rails generate solid_queue_web:install:migrations`

## [1.4.0] - 2026-05-28

### Added

- Slow job webhook alert — set `alert_slow_job_count_threshold` (integer) to fire a webhook whenever the number of currently-running slow jobs meets or exceeds the configured count; requires `slow_job_threshold` to define what "slow" means; uses the same `alert_webhook_url` and `alert_webhook_cooldown` settings as other alert types; event name `slow_job_threshold_exceeded`
- Stale process webhook alert — set `alert_stale_process_threshold` (integer) to fire a webhook whenever the number of stale workers meets or exceeds the configured count; a process is stale when its heartbeat has not been updated within `SolidQueue.process_alive_threshold`; uses the same `alert_webhook_url` and `alert_webhook_cooldown` settings; event name `stale_process_detected`
- Job wait time column — the Running tab now shows a "Wait Time" column displaying how long each claimed job waited in the queue from enqueue to pickup; also included as `wait_time_seconds` in the CSV export for the claimed status
- Eliminate N+1 queries on the queues index — `queue.size` and `queue.paused?` previously fired one query each per queue; both are now pre-computed in the controller with single batch aggregations (`GROUP BY queue_name` for sizes, one `Pause` query for paused state), reducing query count from O(2N+constant) to O(constant) regardless of queue count

## [1.3.0] - 2026-05-27

### Added

- Sticky filter preferences — last-used status tab (Jobs) and time-period pill (Jobs, Failed Jobs, History) are persisted to `localStorage`; revisiting a page via the nav link restores the previous filter automatically; clicking "All" clears the saved period; implemented as a lightweight Stimulus controller (`FiltersController`) with no server-side changes

- Configurable display timezone — `SolidQueueWeb.configure { |c| c.time_zone = "America/New_York" }` renders all dashboard timestamps in the configured zone rather than UTC; uses `in_time_zone` from ActiveSupport; defaults to UTC when not set; a `format_timestamp` helper centralises all timestamp formatting across jobs, failed jobs, history, search, queues, recurring tasks, and the scheduled-job turbo stream update

- Sortable table columns — Jobs, Failed Jobs, and History tables now support server-side sorting via `?sort=` and `?direction=` params; click any column header to sort ascending or descending; sort state is preserved across filter changes, status tab switches, and period buttons; a `sort_header_th` helper generates accessible `<th>` elements with `aria-sort` and direction indicators (↑/↓)

## [1.2.0] - 2026-05-27

### Added

- p99 and standard deviation columns in performance analytics — `JobPerformanceStats` now computes a 99th percentile and population standard deviation for each job class; both columns appear in the Performance table between p95 and Min; high std dev surfaces inconsistent jobs worth investigating

- Failed job trend chart — a "Failures — Last 12 Hours" bar chart card on the dashboard shows how many jobs failed per hour over the last 12 hours; bars are red (distinct from the blue throughput and purple queue depth charts); header shows the total failure count for the window; empty state shown when no failures exist in the period

- Error frequency report — a new Error Summary page (`/jobs/failed_jobs/errors`) groups all failed jobs by error class and message prefix, shows a count per group, and displays a sample backtrace (first 10 lines) in an expandable `<details>` element; groups are sorted by count descending so the most common errors appear first; accessible via an "Error Summary" button on the Failed Jobs page

## [1.1.0] - 2026-05-21

### Added

- Queue depth alert — `alert_queue_thresholds` accepts a hash of `queue_name => ready_job_count`; a webhook fires when any configured queue's ready count meets or exceeds its threshold; cooldown is tracked independently per queue so a busy queue doesn't suppress alerts for others; uses the same `alert_webhook_url` endpoint(s) with `event: "queue_depth_threshold_exceeded"` and `queue_name`, `depth`, and `threshold` fields in the payload
- Multiple webhook targets — `alert_webhook_url` now accepts an array of URL strings; all configured endpoints receive the same payload when the failure threshold is exceeded; a failure posting to one URL is logged and skipped without blocking the remaining targets
- Retry failed job with modified arguments — the Arguments card on the job detail page becomes an editable textarea for failed jobs; editing the JSON and clicking "Retry with these arguments" updates the job record and retries in one step; invalid JSON redirects back with an error message without touching the failed execution

## [1.0.0] - 2026-05-21

### Added

- Bulk scheduled job actions — a "Run All Now" button on the Scheduled tab back-dates all scheduled executions in a single `update_all` call, causing SolidQueue's dispatcher to pick them up immediately; respects the active period filter so only jobs within the current window are promoted
- Priority filter — a `?priority=N` param on the jobs index narrows the list to a specific integer priority value; a select dropdown appears in the search bar when multiple distinct priorities exist in the current status; priority is preserved across status tab switches, period changes, and search; Discard All also respects the active priority filter
- Performance analytics — a new Performance page (`/jobs/performance`) shows per-job-class statistics derived from the history table: run count, average duration, p50, p95, min, and max; rows are sorted by p95 descending so the slowest classes appear first; a period filter (1h / 24h / 7d / All) scopes the dataset; each class name links to the History page pre-filtered to that class; business logic lives in a `JobPerformanceStats` service using a single pluck query with Ruby-side aggregation for DB-agnostic percentile computation
- Metrics / health endpoint — `GET /jobs/metrics.json` returns a JSON document with job counts (`ready`, `scheduled`, `claimed`, `blocked`, `failed`), throughput (`completed_1h`, `completed_24h`), per-queue depth and pause state, and process health (`total`, `healthy`, `stale`, `by_kind`); when `slow_job_threshold` is configured, a `slow_jobs` count is also included; the endpoint goes through the same authentication and `connects_to` middleware as all other routes
- Recurring task "Run Now" — a "Run Now" button on the Recurring Tasks page triggers `task.enqueue(at: Time.current)` to enqueue the job immediately without waiting for its next scheduled run; SolidQueue's `RecurringExecution` deduplication prevents double-enqueuing
- Read replica support — when `connects_to` is set to `{ reading: <role>, writing: <role> }`, the engine automatically routes GET requests to the reading role and mutating requests (POST/DELETE/PATCH) to the writing role via `ActiveRecord::Base.connected_to(role:)`; passing any other hash (e.g. `{ role: :writing }`, `{ shard: :name }`) falls through to `connected_to` directly; defaults to `nil` so single-database setups are unaffected
- Webhook alert config — `alert_webhook_url` and `alert_failure_threshold` settings POST a JSON payload (`event`, `failure_count`, `threshold`, `fired_at`) to any URL when the failed job count meets or exceeds the threshold; fires asynchronously in a background thread so dashboard requests are never blocked; a configurable `alert_webhook_cooldown` (default 3600 s) prevents repeated alerts while the count stays elevated; HTTP errors are logged and swallowed
- Bulk retry with delay — "+5s", "+10s", "+30s", and "+1m" stagger buttons on the Failed Jobs page retry all matched jobs with a configurable interval between each; the first job runs immediately, subsequent jobs are scheduled at incremental offsets; uses per-execution `retry` so `scheduled_at` is respected by SolidQueue's dispatcher; buttons only appear when more than one job is present
- Scheduled job management — "Run Now" promotes a scheduled job to run immediately by back-dating its `scheduled_at`; "+1h", "+24h", and "+7d" buttons push `scheduled_at` forward by the chosen offset; both actions update the execution and the underlying job record; Turbo Stream responses remove the row on "Run Now" and update the `scheduled_at` cell in place on postpone

## [0.9.0] - 2026-05-20

### Added

- Failure rate sparkline per queue — a mini 12-bar chart in the Queues table shows the percentage of jobs that failed (vs. completed) in each of the last 12 hours; bars are red, sized proportionally to the failure rate (0–100 %), and include a tooltip with the hour label and exact percentage; empty hours render as a faint border-colored bar; queues with no activity in the last 12 hours show "—"
- Queue depth trend — a "Queue Depth — Last 12 Hours" card on the dashboard shows estimated queue depth at 12 hourly snapshots; depth at time T is the count of jobs created before T that had not yet finished by T; bars are purple (distinct from the blue throughput and red failure rate charts); the card header shows current depth; empty state shown when no active jobs exist in the window
- Slow job detection — a configurable `slow_job_threshold` setting (default nil = disabled) flags claimed jobs that have been running longer than the threshold; when set, the Running tab gains a "Running For" column showing each job's elapsed time, slow jobs are highlighted with an orange row background and a "slow" badge, and a "Slow Jobs" warning card appears on the dashboard linking to the Running tab

### Changed

- `QueuesController#pause` / `#resume` extracted into `Queues::PausesController#create` / `#destroy`; pause maps to `POST /queues/:name/pause`, resume to `DELETE /queues/:name/pause`
- `Queues::JobsController#discard_all` merged into `#destroy` branching on `params[:id]`, matching the pattern already used in `JobsController`

## [0.8.0] - 2026-05-20

### Added

- CSV export on the jobs, failed jobs, and history pages — an "Export CSV" button downloads all records matching the current filters (status, queue, search term, period) as a named `.csv` file; columns are tailored per view (enqueued_at for jobs, error details for failed jobs, duration and finished_at for history)
- Dashboard quick actions — "Retry All Failed" and "Discard All Blocked" buttons appear as cards on the dashboard when the respective count is non-zero; each includes a confirm dialog and redirects back to the dashboard with a count notice; cards are hidden when everything is healthy
- Dark mode — a ☽/☀ toggle button in the header switches between light and dark themes; preference persists to `localStorage` and falls back to the OS `prefers-color-scheme` on first visit; implemented via a `[data-theme="dark"]` attribute on `<html>` so all CSS custom properties inherit the new palette automatically; badge and flash hardcoded hex colors get explicit dark-mode overrides in a new `_12_dark_mode.css` partial; powered by a new Stimulus `theme_controller`
- Configurable settings via `SolidQueueWeb.configure` — `page_size` (Pagy limit, default 25), `dashboard_refresh_interval` (ms, default 5 000), `default_refresh_interval` (ms, default 10 000 — applies to jobs, processes, and history pages), `search_results_limit` (max results per status in global search, default 25); all settings have safe defaults so zero host-app configuration is required

### Changed

- `FailedJobsController#destroy` and `#discard_all` consolidated into a single `destroy` action branching on `params[:id]`; `discard_all` route maps to `destroy` via `action:` option
- `FailedJobsController#retry` and `#retry_all` extracted into a new `RetryFailedJobsController#create` action with the same single/bulk branching pattern
- `JobsController#destroy` and `#discard_all` consolidated the same way, preserving the Turbo Stream response for the single-job path

## [0.7.0] - 2026-05-20

### Added

- Queue latency detail — oldest ready job age per queue; replaces the verbose `human_latency` string with `format_duration` output (e.g. "1h 12m"); color-coded orange above 1 hour, red above 24 hours; hovering shows the absolute UTC timestamp of the oldest waiting job; empty queues show "—"
- Queue throughput columns — Done (24h) and Failed (24h) counts per queue on the Queues page; powered by two grouped COUNT queries; Done renders in green, Failed renders in red when non-zero
- Auto-refresh on the Job History page — wraps the page in a turbo-frame polled every 10 seconds, matching the jobs and processes pages; pauses when the browser tab is hidden
- Job History page (`/jobs/history`) — browsable list of all finished jobs (`finished_at IS NOT NULL`) ordered by most-recent-first; columns show class name (links to job detail), queue (clickable queue filter), duration (formatted as `Xs`, `Xm Xs`, or `Xh Xm`), and finished timestamp; filterable by time period (1h / 24h / 7d), queue name, and class name search; paginated; "Done (1h)" and "Done (24h)" dashboard stat cards now link to the history page pre-filtered by period; "History" nav link added between Jobs and Failed
- Throughput section on the dashboard — "Done (1h)" and "Done (24h)" stat cards show completed-job counts; a full-width "Throughput — Last 12 Hours" card displays a pure-CSS bar chart (12 hourly buckets, oldest left → newest right, tick labels every 3 bars) with no JavaScript or charting library; powered by a single `pluck(:finished_at)` query with Ruby-side grouping for DB-agnostic compatibility; seed data updated with a realistic daily-pattern distribution so the chart shows meaningful data out of the box

### Changed

- CSS split into 10 focused partial files (`_01_base.css` through `_10_responsive.css`); `inline_styles` helper globs `_*.css` files in sort order — runtime output is identical, authoring is easier

### Fixed

- Auto-refresh no longer wipes checkbox selections — refresh skips its tick whenever any checkbox inside the turbo-frame is checked and resumes once selections are cleared or submitted

## [0.6.0] - 2026-05-19

### Added

- Job selection and targeted bulk actions — checkboxes on the jobs index (ready/scheduled/blocked) and failed jobs index; a selection bar appears above the table showing the count and action buttons ("Discard Selected" for jobs, "Retry Selected" / "Discard Selected" for failed jobs); select-all checkbox in the table header; powered by a new `selection` Stimulus controller that injects checked IDs into a hidden form on submit; uses nested singular resources (`Jobs::SelectionsController`, `FailedJobs::SelectionsController`) following Rails conventions
- Auto-refresh for dashboard, jobs list, and processes — a `refresh` Stimulus controller polls the current page at a configurable interval (5 s for dashboard, 10 s for jobs/processes) and swaps the matching `<turbo-frame>` content in place; polling pauses when the browser tab is hidden and resumes with an immediate refresh when the tab becomes visible again
- Time-based period filter (`?period=1h|24h|7d`) on the jobs and failed jobs indexes — filters results by enqueued timestamp; period pills render inline with the search bar, right-justified; active period is preserved across status tab switches, search, queue filters, and bulk actions
- Global job search at `/jobs/search` — queries all execution models (ready, scheduled, claimed, blocked, failed) by class name substring; results grouped by status with match count and a "View all →" link; native `<datalist>` autocomplete pre-populated from all known job class names; auto-submits on datalist selection via the `search` Stimulus controller
- `spec/dummy/bin/rails` — enables `bin/rails console` and `bin/rails server` from the dummy app directory during local development

## [0.5.5] - 2026-05-19

### Added

- Failed jobs search: `?q=` param filters by class name substring on the failed jobs index
- Failed jobs queue filter: queue names in the failed jobs table are clickable links that filter to that queue; a "Filtering by queue" indicator appears with a clear link
- Queue-scoped Retry All / Discard All on failed jobs: bulk actions apply only to the active queue/search filter and redirect back preserving those params
- Blocked job detail: job show page displays "Blocked Until" (`BlockedExecution#expires_at`) when the job has a blocked execution
- Queue-scoped jobs view at `/jobs/queues/:queue_name/list` — dedicated `Queues::JobsController` with status tabs, class name search, per-row discard (Turbo Stream), and Discard All scoped to the queue; navigated to by clicking queue names on the global jobs list

### Changed

- `JobsController#index` no longer filters by queue — queue filtering is owned by `Queues::JobsController`
- `JobsController#show` no longer assigns `@failed_execution` / `@blocked_execution`; view reads associations directly from `@job` (already eager-loaded)
- Removed stale `queue: @queue` from status tab links in the jobs index (param was always `nil` after the queue controller refactor)

### Fixed

- Job detail links inside the turbo frame on the jobs index rendered "Content missing" because the show page has no matching frame; fixed with `data-turbo-frame="_top"` so navigation breaks out to a full page load

## [0.5.0] - 2026-05-19

### Added

- Job class name search field on the jobs index — filters the current status tab by class name substring; case-insensitive; persists across status tab switches
- Dynamic search: auto-submits after 4 characters typed or on clear (300 ms debounce) via a Stimulus `search` controller (`app/javascript/solid_queue_web/search_controller.js`)
- Turbo Frame navigation on the jobs index — status filter tabs, search, and pagination update only the table region without a full page reload; URL is pushed to browser history so filtering is bookmarkable
- `importmap-rails` integration: engine registers its own `config/importmap.rb`, adds `app/javascript/` to the asset pipeline, and loads via `javascript_importmap_tags` in the layout
- `@hotwired/turbo` imported in the engine entry point so Turbo is active within the engine's own layout
- Recurring Tasks page (`/jobs/recurring_tasks`) showing key, cron schedule, job class or command, queue, next run time, last run time, and Static/Dynamic badge; eager loads recurring executions to avoid N+1
- Recurring Tasks stat card on the dashboard (cyan, links to the page)
- "View recurring tasks" button in the dashboard Quick Links
- `sqd-badge--static` (green) and `sqd-badge--dynamic` (purple) badge variants
- Hamburger toggle nav for viewports narrower than 576px — three-bar button opens a full-width dropdown with vertically stacked links; no JS file required
- `sqd-grid-2` utility class for responsive two-column layouts (collapses to one column at ≤768px)
- `.sqd-sr-only` utility class for visually-hidden text
- `:focus-visible` focus ring (2px primary blue) for keyboard navigation
- `aria-expanded` on the mobile nav toggle, kept in sync on open/close
- `role="status"` on notice flash messages and `role="alert"` on alert flash messages
- `aria-label="Main"` on the primary navigation landmark
- `aria-current="page"` on the active navigation link
- `scope="col"` on all table header cells
- Visually-hidden "Actions" label on empty action column headers

### Changed

- Dashboard stat card order aligned with nav: Ready, Scheduled, Running, Blocked, Failed, Queues, Recurring, Processes
- Stat grid minimum cell width reduced from 150px to 128px so all 8 cards fit in one row
- Navbar title and links constrained to the same max-width as page content so they align horizontally with the dashboard
- Page headers stack vertically on mobile (≤640px)
- Stat grid uses a smaller minimum cell width on mobile
- Cards scroll horizontally on mobile to accommodate wide tables
- Main content padding reduced on mobile

## [0.4.0] - 2026-05-18

### Added

- Turbo Streams on the jobs list — discarding a single job removes its row in place; the last job swaps the card to an empty state without a full page reload
- Turbo Frame on the jobs list — status filter tabs, queue filter links, Discard All button, and pagination all update in place without reloading the page header or flash
- Dashboard stat cards are now clickable links to their respective filtered views
- GitHub Releases created automatically with CHANGELOG notes when a version tag is pushed
- `turbo-rails >= 2.0` added as a runtime dependency

### Changed

- `JobsController` refactored: execution model mapping moved to `EXECUTION_MODELS` hash constant, eliminating two `case` statements
- `JobsController#destroy` and `#discard_all` share a `before_action :set_status_and_queue` and a `filtered_scope` helper, removing duplicated param reading and scope building

### Fixed

- Test suite reaches 100% line coverage; rescue paths, `derive_status` branches (scheduled, finished), and the authentication block are all exercised

## [0.3.0] - 2026-05-18

### Added

- Processes page showing workers, dispatchers, and supervisors with kind, PID, host, metadata, last heartbeat, and Healthy/Stale status
- Queue pause / resume — Pause and Resume buttons per row on the Queues page
- Pagination for jobs and failed jobs lists via pagy (25 per page)
- Jobs URL segment renamed from `/jobs/jobs` to `/jobs/list`
- Job detail page showing status, queue, priority, arguments (pretty-printed JSON), and full error backtrace for failed jobs
- Retry/Discard action buttons on the detail page based on job status
- Job class names on the jobs and failed jobs index pages link to the detail page
- Retry and discard actions on individual failed jobs
- Bulk "Retry All" and "Discard All" actions for failed jobs
- Discard action on individual ready, scheduled, and blocked jobs
- Bulk "Discard All" action for ready, scheduled, and blocked jobs (scoped to current queue filter)
- Roadmap section added to README with planned features and contribution guidelines

### Fixed

- Failed jobs view now renders error class and message correctly (seed data format and missing CSS class)

## [0.2.0] - 2026-05-18

### Added

- CI release job publishes gem to RubyGems automatically on version tags
- Trusted Publishing via OIDC — no stored API keys required

### Fixed

- CSS is now inlined in the layout via a helper — no asset pipeline (Sprockets/Propshaft) required in the host app
- Renamed gem from `solid_queue_dashboard` to `solid_queue_web` to avoid conflict with an existing RubyGems package

## [0.1.0] - 2026-05-18

### Added

- Rails engine scaffold with isolated namespace `SolidQueueWeb`
- Configurable authentication hook (`SolidQueueWeb.authenticate`)
- Read-only dashboard with stat cards for ready, scheduled, running, blocked, and failed jobs
- Queues index page showing all queues sorted by name
- Jobs index with status filter tabs (ready, scheduled, claimed, blocked, failed) and per-queue filtering
- Failed jobs index page
- Minimal inline CSS with stat cards, tables, and status badges — no external CSS framework required
- Runtime dependencies: `rails >= 8.1.3`, `solid_queue >= 1.0`
- RSpec test suite with dummy Rails app for engine request specs
- SimpleCov code coverage reporting
- RuboCop linting via `rubocop-rails-omakase`; `bundle exec rake` runs the full suite
- CI workflow with lint (RuboCop) and test (RSpec) matrix across Ruby 3.3, 3.4, and 4.0
- `bin/release` script for versioned gem releases

[Unreleased]: https://github.com/eclectic-coding/solid_queue_web/compare/v1.6.0...HEAD
[1.6.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v1.6.0
[1.5.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v1.5.0
[1.4.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v1.4.0
[1.3.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v1.3.0
[1.2.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v1.2.0
[1.1.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v1.1.0
[1.0.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v1.0.0
[0.9.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v0.9.0
[0.8.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v0.8.0
[0.7.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v0.7.0
[0.6.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v0.6.0
[0.5.5]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v0.5.5
[0.5.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v0.5.0
[0.4.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v0.4.0
[0.3.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v0.3.0
[0.2.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v0.2.0
[0.1.0]: https://github.com/eclectic-coding/solid_queue_web/releases/tag/v0.1.0
