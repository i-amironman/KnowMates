# KnowMates Play Store MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship KnowMates, an original Android app in the visual spirit of the attached dark mock, where adults teach a skill, earn time credits, and spend those credits to learn something else, on a free open-source stack whose monthly infrastructure bill stays at zero through 1 lakh registered users.

**Architecture:** A Flutter client talks only to a stateless Go HTTP API. PostgreSQL 16 is the source of truth, including an append-only credit ledger and the text sent inside a session call. Valkey holds rate limits, the short-lived discovery cache, and the live call handshake. A session call is phone-to-phone WebRTC. coturn on the same VM relays media only when the two phones cannot reach each other. Caddy terminates TLS and serves avatars from disk. Mail goes out through SMTP. The phone receives push through FCM, and the API calls the FCM HTTP v1 API directly. Docker Compose runs Postgres, Valkey, the API, and Caddy. The laptop uses that file for tests. Production is the same file plus coturn on one Linux VM behind Cloudflare's free proxy.

**Tech Stack:** Flutter stable (Dart 3), `flutter_webrtc`, Go 1.23, PostgreSQL 16, Valkey 8 (Redis protocol), coturn, Caddy 2, Cloudflare DNS and proxy (free), Cloudflare STUN `stun:stun.cloudflare.com:3478` (free, unlimited), Cloudflare R2 for off-box backups (free tier), Brevo SMTP (free tier), FCM HTTP v1 (free). Host: Oracle Cloud Always Free Ampere VM in Mumbai. No Terraform and no AWS. No LiveKit Cloud, Daily, Agora, or any other metered video service.

## Global Constraints

- Product name is KnowMates. Android `applicationId` is `app.knowmates`, set in Task 2, and never changed after the first Play upload. Before that upload, confirm the name, domain, and Play listing are available.
- Launch audience is ages 18–23. The server rejects any account whose date of birth makes them under 18. No teen mode in this plan.
- No in-app payments and no card data. A scheduled session has a built-in call for its two participants: camera, microphone, one screen share, and text stored on that session. Phones connect directly. The API forwards the handshake through Valkey and stores the chat text. coturn relays a call only when a direct path fails. An optional `https` backup link (Meet, Zoom, or similar) is stored when someone pastes one. Audio and video stay on the two phones. Postgres stores the chat text.
- No LLM in P0. Matching is a deterministic SQL score. The welcome screen does not claim the product is AI-powered.
- Visual target is the attached mock: near-black purple field, magenta wordmark, glass cards, orange-to-pink primary button, five-tab bottom bar. Layout and color are original code. Do not copy the Dribbble file, its stock portraits, or its illustration assets.
- Every mutation checks the authenticated user. Clients cannot set credit balances.
- Production is one Linux VM in Mumbai running `deploy/docker-compose.prod.yml`. No managed database, load balancer, cache, or autoscaler. Monthly infrastructure cost is $0 through 1 lakh registered users. The only cash costs are a domain name (about $10–15 a year) and the Play Console registration ($25 once). Do not add a paid cloud service to reach that user count.
- The API process stores no session state. A second VM runs the same container image when the first is busy. Ledger writes use `DATABASE_URL`. Discovery uses `DATABASE_READ_URL` when it is set, and the primary when it is empty.
- P0 scope ends at Play internal testing with auth, skills profile, discovery, matching, learning requests, scheduling, the credit ledger, the in-app session call, block, and report. Learning plans, the request inbox, portfolio, groups, and learned ranking are later plans.

## Brand

KnowMates is Knowledge + Mates. The tagline is "Learn from people. Grow together."

Everyone has something to teach and something to learn. The name covers coding, languages, design, cooking, photography, music, and any skill after those. The personality is social, welcoming, and community-driven. Interface copy invites people in. It reads like a community, in a warm voice.

- Wordmark: **Know** in magenta, **Mates** in white.
- Tagline, used as the large welcome headline: "Learn from people. Grow together."
- Supporting line: "Everyone has something to teach, and something to learn."
- Play title: KnowMates. Short description: "Learn from people. Grow together."

## Cloud

Open-source software on a free VM. The app binary does not change when a second VM is added or when `DATABASE_READ_URL` starts pointing at a replica. Nothing in this table has a usage meter.

| Job | Software | Launch, through about 10,000 registered | At 1 lakh registered |
| --- | --- | --- | --- |
| API | Go in Docker, behind Caddy | 1 container on the VM | Same image. Add a second always-free VM only if the first CPU stays hot. |
| Database | PostgreSQL 16 | Docker volume on the VM | Same primary. A streaming replica plus `DATABASE_READ_URL` only if discover shows up in CPU. |
| Connections | Direct `pgx` pool, max 10 per process | | A second API process uses its own pool of 10. No proxy. |
| Cache | Valkey 8, Redis protocol | 1 container | Same container. A 30-second discover cache is a few megabytes at this size. |
| Avatars | VM disk, served by Caddy | JPEG recompressed to a 512 px long edge | 1 lakh photos at about 200 KB is about 20 GB, inside the disk quota. |
| TLS and DNS | Caddy, Cloudflare free proxy and DNS | | Same hostname. |
| Email | SMTP. Launch host is Brevo's free tier | 300 messages a day | Same `Sender` interface. A busier day changes `SMTP_HOST` only. |
| Push | FCM HTTP v1 from the API | | Same call. The phone uses FCM because that is how Android delivers pushes. |
| Call relay | coturn on the VM, host network | UDP and TCP 3478, UDP relay 49160–49200 | Same container. A fully relayed hour is about 450 MB of the 10 TB outbound quota, which covers on the order of 20,000 such hours a month. Direct calls use none of it. |
| Secrets | `.env` on the VM, mode `600`, owner root | `AUTH_SECRET`, database URL, SMTP password, FCM file, `TURN_SECRET` | Never committed. |
| Logs | Docker json logs, 7-day rotation | | `docker logs`. |
| Backups | `pg_dump` daily, copy to Cloudflare R2 | 7 local files plus the R2 copy | R2's free 10 GB holds these dumps. |

Host, confirmed in the Oracle console before creating the instance: Always Free Ampere quota of 4 OCPU, 24 GB RAM, 200 GB block storage, and 10 TB outbound per month, region `ap-mumbai-1`. Launch shape is 2 OCPU, 12 GB RAM, 100 GB volume. The leftover 2 OCPU, 12 GB, and 100 GB stay unused so a second VM still fits in the free quota.

Network: Cloudflare proxies `api.<domain>` (orange-cloud A record). `turn.<domain>` is a grey-cloud A record to the same VM, because Cloudflare's proxy does not carry TURN's UDP. The VM security list allows 22 from the operator's IP, 80/443 from the internet, and UDP/TCP 3478 plus UDP 49160–49200 from the internet. Postgres and Valkey publish no ports. Caddy presents a Cloudflare origin certificate. Cloudflare SSL mode is Full (strict). No NAT gateway, no load balancer, no public database. The call handshake uses `wss` on `api.<domain>`, which the free proxy already allows.

Bill through 1 lakh registered users: $0 per month for compute, database, cache, the call relay, TLS, DNS, push, and backups. Domain about $10–15 per year. Play Console $25 once. Brevo's published free tier is 300 emails a day; that covers a year of signups spread out, and a launch-day spike is fixed by pointing SMTP at another host.

Workload this shape is sized for: 1 lakh registered, about 20,000 of them active in a month, about 10 discover loads each on an active day. That is about 200,000 discover reads a day, a few queries a second on average and a few dozen at a peak. The candidate query is indexed and limited to 100 rows, and the JSON is cached 30 seconds. Ledger writes happen when someone books or completes a session, not when they scroll. A 2-OCPU Postgres handles that.

`ponytail:` one VM is the ceiling. A dead disk loses rows newer than the last off-box dump, so R2 must be set before real users exist. A fully relayed call hour is about 450 MB because each phone sends about 500 kbps and coturn forwards both streams; 10 TB covers about 20,000 such hours a month. Credits already limit how often a session can be booked. Upgrade path, in order, with no application rewrite: second always-free VM running only the API, move coturn onto the leftover always-free capacity if relayed calls are what fills the 10 TB, then a Postgres streaming replica on `DATABASE_READ_URL`, then a paid VPS only after the free quota is actually full. Do not add ECS, RDS, ElastiCache, a load balancer, or a metered video vendor on the way there.

Oracle sometimes has no free Ampere capacity, and an idle always-free account can be closed. The API staying up counts as use. The compose file has no Oracle API calls, so a closed account is a move to any other Linux VM, not a rewrite.

## Capacity

One VM runs identical stateless API containers. Discovery reads may move to a replica by setting `DATABASE_READ_URL`. Credit settlement always uses the primary inside one transaction. Avatar bytes live on the disk Caddy serves, so API containers stay replaceable. Call media is either phone-to-phone or relayed by coturn. The API process holds no call state: a handshake message is published to Valkey and any API process subscribed to that session can forward it. There is no autoscaler that can spend money while you sleep.

---

## File structure

```text
apps/mobile/                          Flutter app
  lib/main.dart                       bootstrap, ProviderScope-free controllers
  lib/theme/app_colors.dart           tokens from the mock
  lib/theme/app_theme.dart
  lib/router.dart                     go_router table
  lib/api/client.dart                 bearer client, 401 refresh
  lib/auth/auth_controller.dart
  lib/screens/welcome_screen.dart     mock screen 1
  lib/screens/sign_in_screen.dart
  lib/screens/sign_up_screen.dart
  lib/screens/shell_screen.dart       five-tab shell
  lib/screens/home_screen.dart        mock screen 3
  lib/screens/discover_screen.dart    mock screen 2
  lib/screens/person_screen.dart
  lib/screens/requests_screen.dart
  lib/screens/sessions_screen.dart
  lib/screens/call_screen.dart        in-app session call
  lib/screens/profile_screen.dart
  lib/screens/wallet_screen.dart
  lib/call/join_window.dart           same 10-minute rule as the server
  test/widget_test.dart
  test/credit_copy_test.dart
  test/join_window_test.dart

services/api/
  cmd/api/main.go
  internal/http/server.go
  internal/auth/password.go
  internal/auth/tokens.go
  internal/credits/ledger.go
  internal/call/join.go             who may enter, and when
  internal/call/turn.go             one-hour coturn REST credentials
  internal/call/signal.go           Valkey fan-out for one session
  internal/match/score.go
  internal/store/store.go
  internal/avatar/store.go          disk, Caddy serves the files
  internal/mail/mail.go             log sender in tests, SMTP in production
  migrations/001_init.sql
  ledger_test.go
  score_test.go
  Dockerfile

deploy/docker-compose.yml           laptop Postgres and Valkey
deploy/docker-compose.prod.yml      Caddy, API, Postgres, Valkey, coturn
deploy/Caddyfile
deploy/backup.sh                    daily pg_dump, copy to R2 when configured
deploy/.env.example
docs/privacy-policy.html          served at https://api.<domain>/privacy
```

Each file owns one job. Screens call `ApiClient`. SQL lives in the store and in migrations. Credit math lives only in `internal/credits`. Call admission and TURN credentials live only in `internal/call`.

---

## Data model

```sql
-- migrations/001_init.sql
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
  id            uuid PRIMARY KEY,
  email         citext NOT NULL UNIQUE,
  password_hash text NOT NULL,
  display_name  text NOT NULL DEFAULT '',
  bio           text NOT NULL DEFAULT '',
  avatar_path   text NOT NULL DEFAULT '',
  birth_date    date NOT NULL,
  timezone      text NOT NULL,
  languages     text[] NOT NULL DEFAULT '{}',
  profile_ready boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE skills (
  id    uuid PRIMARY KEY,
  slug  text NOT NULL UNIQUE,
  name  text NOT NULL
);

CREATE TABLE user_skills (
  user_id      uuid NOT NULL REFERENCES users(id),
  skill_id     uuid NOT NULL REFERENCES skills(id),
  role         text NOT NULL CHECK (role IN ('teach', 'learn')),
  proficiency  smallint NOT NULL CHECK (proficiency BETWEEN 1 AND 5),
  PRIMARY KEY (user_id, skill_id, role)
);

CREATE TABLE availability (
  id          uuid PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES users(id),
  weekday     smallint NOT NULL CHECK (weekday BETWEEN 0 AND 6), -- 0 Monday
  start_min   smallint NOT NULL CHECK (start_min BETWEEN 0 AND 1439),
  end_min     smallint NOT NULL CHECK (end_min BETWEEN 1 AND 1440),
  CHECK (end_min > start_min)
);

CREATE TABLE refresh_tokens (
  id         uuid PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES users(id),
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz
);

CREATE TABLE swap_requests (
  id          uuid PRIMARY KEY,
  learner_id  uuid NOT NULL REFERENCES users(id),
  teacher_id  uuid NOT NULL REFERENCES users(id),
  skill_id    uuid NOT NULL REFERENCES skills(id),
  goal        text NOT NULL CHECK (char_length(goal) BETWEEN 8 AND 280),
  status      text NOT NULL CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  CHECK (learner_id <> teacher_id)
);

CREATE TABLE sessions (
  id          uuid PRIMARY KEY,
  request_id  uuid NOT NULL UNIQUE REFERENCES swap_requests(id),
  learner_id  uuid NOT NULL REFERENCES users(id),
  teacher_id  uuid NOT NULL REFERENCES users(id),
  skill_id    uuid NOT NULL REFERENCES skills(id),
  starts_at   timestamptz NOT NULL,
  ends_at     timestamptz NOT NULL,
  meeting_url text,
  status      text NOT NULL CHECK (status IN ('scheduled', 'completed', 'cancelled', 'disputed')),
  learner_done boolean NOT NULL DEFAULT false,
  teacher_done boolean NOT NULL DEFAULT false,
  CHECK (ends_at > starts_at)
);

CREATE TABLE session_messages (
  id         uuid PRIMARY KEY,
  session_id uuid NOT NULL REFERENCES sessions(id),
  sender_id  uuid NOT NULL REFERENCES users(id),
  body       text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 500),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE credit_ledger (
  id         uuid PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES users(id),
  session_id uuid REFERENCES sessions(id),
  delta      integer NOT NULL CHECK (delta <> 0),
  reason     text NOT NULL CHECK (reason IN (
               'starter_grant', 'session_hold', 'session_release', 'teach_completed'
             )),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, user_id, reason)
);

CREATE TABLE reviews (
  id          uuid PRIMARY KEY,
  session_id  uuid NOT NULL REFERENCES sessions(id),
  reviewer_id uuid NOT NULL REFERENCES users(id),
  rating      smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  body        text NOT NULL DEFAULT '',
  UNIQUE (session_id, reviewer_id)
);

CREATE TABLE blocks (
  blocker_id uuid NOT NULL REFERENCES users(id),
  blocked_id uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

CREATE TABLE reports (
  id             uuid PRIMARY KEY,
  reporter_id    uuid NOT NULL REFERENCES users(id),
  target_user_id uuid NOT NULL REFERENCES users(id),
  session_id     uuid REFERENCES sessions(id),
  reason         text NOT NULL CHECK (reason IN ('harassment', 'spam', 'safety', 'other')),
  details        text NOT NULL DEFAULT '',
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX user_skills_skill_role ON user_skills (skill_id, role);
CREATE INDEX swap_requests_teacher_status ON swap_requests (teacher_id, status);
CREATE INDEX swap_requests_learner_status ON swap_requests (learner_id, status);
CREATE INDEX sessions_learner ON sessions (learner_id, starts_at);
CREATE INDEX sessions_teacher ON sessions (teacher_id, starts_at);
CREATE INDEX session_messages_session ON session_messages (session_id, created_at);
CREATE INDEX credit_ledger_user ON credit_ledger (user_id);
```

Balance is always `COALESCE(SUM(delta), 0)` for that user. Nothing updates a balance column.

Starter grant is `+2` with reason `starter_grant` and `session_id` NULL, inserted once when `profile_ready` flips to true. The partial unique index that enforces one grant:

```sql
CREATE UNIQUE INDEX one_starter_grant ON credit_ledger (user_id) WHERE reason = 'starter_grant';
```

Cold start: a new member cannot learn until they have a credit. The grant lets them book a first session. After that, teaching is how the wallet refills.

Ledger rules, all inside one database transaction:

| Event | Rows |
| --- | --- |
| Profile becomes ready | learner `+2` `starter_grant` |
| Session scheduled | learner `-1` `session_hold`, only if balance ≥ 1 |
| Session cancelled | learner `+1` `session_release` |
| Both participants mark complete | teacher `+1` `teach_completed`; learner stays debited by the hold |
| Report filed | insert `reports`. If the session is still `scheduled`, set `disputed` and do not settle. A completed session is not auto-reversed. |

`UNIQUE (session_id, user_id, reason)` makes settle and cancel safe to retry.

---

## HTTP API

Base path `/v1`. Auth header `Authorization: Bearer <access>`. Access token TTL 15 minutes. Refresh token TTL 30 days, stored hashed, rotated on use.

| Method | Path | Auth | Body / behavior |
| --- | --- | --- | --- |
| POST | `/v1/auth/sign-up` | no | `{email, password, birthDate, timezone}` → `{access, refresh}` or 400 if under 18 |
| POST | `/v1/auth/sign-in` | no | `{email, password}` |
| POST | `/v1/auth/refresh` | no | `{refresh}` → new pair, old refresh revoked |
| POST | `/v1/auth/sign-out` | yes | revokes the presented refresh |
| DELETE | `/v1/me` | yes | deletes the account (Play requirement) |
| GET | `/v1/me` | yes | profile, languages, skills, balance, `profileReady`, `sessionsCompleted` |
| PATCH | `/v1/me` | yes | name, bio, languages, timezone, and `ready: true` which calls `MarkReady` |
| PUT | `/v1/me/skills` | yes | `{teach:[{skillId, proficiency}], learn:[...]}` replaces the set |
| PUT | `/v1/me/availability` | yes | `{slots:[{weekday, startMin, endMin}]}` replaces the set |
| POST | `/v1/me/avatar` | yes | `image/jpeg` body, max 1 MB |
| GET | `/v1/skills?q=` | yes | skill catalog, seeded |
| GET | `/v1/discover?skillId=&language=&weekday=` | yes | ranked people, limit 20, `?cursor=` |
| GET | `/v1/people/{id}` | yes | public profile, hidden if blocked |
| POST | `/v1/requests` | yes | `{teacherId, skillId, goal}` |
| POST | `/v1/requests/{id}/accept` | teacher | |
| POST | `/v1/requests/{id}/decline` | teacher | |
| POST | `/v1/requests/{id}/cancel` | learner, only while pending | |
| POST | `/v1/sessions` | either party of an accepted request | `{requestId, startsAt, endsAt, meetingUrl?}` stores an `https` link when present and creates the hold |
| POST | `/v1/sessions/{id}/call/ticket` | participant, join window open | STUN URL, TURN URL, one-hour username and password |
| GET | `/v1/sessions/{id}/call` | participant, join window open | WebSocket. Handshake, chat, and presence for this session |
| POST | `/v1/me/device` | yes | `{token}` saves the FCM registration token |
| POST | `/v1/sessions/{id}/complete` | participant | sets that side's done flag; settles when both are true |
| POST | `/v1/sessions/{id}/cancel` | participant | release hold if still scheduled |
| POST | `/v1/sessions/{id}/reviews` | participant, session completed | `{rating, body}` |
| GET | `/v1/wallet` | yes | `{balance, entries}` newest 50 |
| POST | `/v1/blocks` | yes | `{userId}` |
| DELETE | `/v1/blocks/{userId}` | yes | |
| POST | `/v1/reports` | yes | `{userId, sessionId?, reason, details}` |
| GET | `/healthz` | no | `ok` |

Errors are `{"error":"machine_code"}`. Codes used by the client: `underage`, `email_taken`, `bad_credentials`, `insufficient_credits`, `not_found`, `forbidden`, `conflict`, `bad_meeting_url`, `call_closed`, `chat_limited`, `email_unverified`.

---

## Call

One session, two people. Join is allowed when `status = scheduled` and `now >= starts_at - 10 minutes`. It stays open after `ends_at` until the session is completed, cancelled, or disputed. Hanging up leaves the session `scheduled` and leaves the credit hold in place. Completion is still the two done-flags in Task 10.

The phone gathers ICE with Cloudflare's free STUN server, then tries a direct path, then TURN. Video is capped at 500 kbps. Screen share replaces the camera track and is capped at 800 kbps, so a relayed hour stays near 450 MB. The teacher creates the WebRTC offer once the other person has joined. The learner only answers. That removes offer glare.

`POST /v1/sessions/{id}/call/ticket` returns:

```json
{
  "stun": ["stun:stun.cloudflare.com:3478"],
  "turn": ["turn:turn.<domain>:3478?transport=udp", "turn:turn.<domain>:3478?transport=tcp"],
  "username": "<unix expiry>:<user id>",
  "password": "<base64 hmac-sha1>",
  "ttlSeconds": 3600
}
```

The password is the coturn REST credential: HMAC-SHA1 of the username keyed with `TURN_SECRET`. When `TURN_SECRET` is empty the `turn` array is empty, which is how laptop tests run without coturn.

The WebSocket speaks JSON text frames. The server publishes each frame to Valkey channel `call:{sessionID}` and forwards a frame to a socket only when `from` is the other user.

| type | Persisted | Meaning |
| --- | --- | --- |
| `peer` | no | `{from, joined}`. Sent on connect and on disconnect. |
| `offer`, `answer`, `ice` | no | SDP or one ICE candidate. |
| `share` | no | `{on: true}` or `{on: false}`. |
| `hangup` | no | The other side returns to the session screen. |
| `chat` | yes | `{id, from, body, createdAt}` after insert. Body is 1–500 characters. |
| `history` | no | Server sends `{messages:[...]}` of the latest 100 rows, oldest first, on connect. |
| `error` | no | `{error:"call_closed"}` or `{error:"chat_limited"}`, then the server closes. |

A user may send 30 chat rows a minute. The counter is Valkey key `chat:{sessionID}:{userID}` with a 60-second TTL. The 31st returns `chat_limited`.

`ponytail:` coturn allows 40 relay allocations and UDP ports 49160–49200. Ceiling is about twenty simultaneous relayed calls on this VM. Upgrade path is to raise `--total-quota`, `--max-port`, and the Oracle security list together. A second API process needs no call rewrite because the fan-out is Valkey, not a map in the process.

---

## Matching

Hard filters, all required:

- Candidate has `role = teach` for the requested skill.
- Viewer has `role = learn` for that skill, or explicitly passed `skillId` they want.
- Neither user has blocked the other.
- Candidate `profile_ready` and not self.

Score, computed in Go over the SQL candidate page (page size 100, return top 20):

```go
package match

type Input struct {
    LanguageMatch   bool
    OverlapMinutes  int
    ProficiencyGap  int // teacher proficiency minus learner proficiency
    RatingAvg       float64
    RatingCount     int
}

func Score(in Input) int {
    s := 50 // skill already matched
    if in.LanguageMatch {
        s += 20
    }
    hours := in.OverlapMinutes / 60
    if hours > 15 {
        hours = 15
    }
    s += hours
    if in.ProficiencyGap >= 1 && in.ProficiencyGap <= 3 {
        s += 10
    }
    if in.RatingCount >= 3 {
        s += int(in.RatingAvg) // 1..5
    }
    return s
}
```

`ponytail:` scoring loads at most 100 candidates per request and sorts in memory. Ceiling is a popular skill with tens of thousands of teachers, where this misses people outside the page. Upgrade path is a generated `match_score` column maintained on write, ordered by index.

Discovery cache key `disc:{viewer}:{skill}:{lang}:{weekday}` in Valkey, TTL 30 seconds. Invalidate is unnecessary at that TTL. Local tests use the same Redis protocol against the Compose `valkey` service (`REDIS_URL`).

---

## Screens (mapped to the mock)

Bottom bar, left to right. The mock's gamepad is not a feature in this product; the fifth tab is Profile so wallet, blocks, and account deletion are one tap away.

| Tab | Icon | Screen |
| --- | --- | --- |
| Discover | people-network | Card stack inspired by mock screen 2 |
| Requests | heart | Incoming and outgoing learning requests |
| Home | sparkle, center, raised | Mock screen 3: greeting, orb, four stats, active skill |
| Sessions | school cap | Upcoming and completed sessions. Join opens the call. |
| Profile | person | Edit skills, availability, wallet link, sign out, delete account |

Pre-auth flow: Welcome (mock screen 1) → Sign up (email, password, birth date, timezone) → Sign in. After sign-in, if `profile_ready` is false, a three-step sheet: name and languages, skills, weekly hours. Then Home.

Welcome copy:

- Wordmark: **Know** in magenta, **Mates** in white.
- Arc line: "Everyone has something to teach, and something to learn."
- Headline, the tagline, shown once: "Learn from people." with "Learn" in magenta, then "Grow together."
- Button: "Get Started".

Home copy:

- "Welcome back,"
- "KnowMates" with "Know" in magenta and "Mates" in a rounded outline chip.
- Subline: "Learn from people. Grow together."
- Stat tiles: Sessions, Time Tokens, Teaching, Learning.
- Bottom card: the skill they are currently learning, session count, average rating they have received as a teacher (or "New" when `RatingCount < 3`).

Discover card:

- Name, years derived from account age only if we refuse to invent "5 years experience". Show joined month instead of a fake experience claim.
- One-line bio.
- Up to two teach-skill chips.
- Photo or initial avatar. Online pill only when `last_seen` is under 2 minutes. P0 has no presence channel, so the pill is omitted until a later plan. Do not paint a fake "Online" badge.
- Actions: Request (heart), Skip (x), Profile (i).
- Languages as text labels with emoji flags for the seeded set `en`, `es`, `hi` only.
- Footer counts: sessions taught, reviews received, and a proficiency label: 1 Basics, 2 Guided, 3 Practice, 4 Deep dive, 5 Mentor.

Colors, used everywhere:

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF120818);
  static const card = Color(0xFF24162F);
  static const cardEdge = Color(0xFF3A2748);
  static const magenta = Color(0xFFFF4D8D);
  static const orange = Color(0xFFFF8A3D);
  static const pink = Color(0xFFFF2E93);
  static const text = Color(0xFFF7F2FB);
  static const muted = Color(0xFFB7A8C9);
  static const star = Color(0xFFFFC857);
}
```

Primary button is a stadium `LinearGradient(colors: [AppColors.orange, AppColors.pink])`, height 56, full width.

Orb on Home is a `CustomPainter` radial gradient plus 40 dots on a circle. It does not use a network image and it does not animate on a timer (static paint keeps the first build cheap; a later plan can add a single animation controller).

---

## Phase 0 — Repo, local stack, design system, welcome screen

This phase produces a phone UI you can scroll, backed by a database that answers `/healthz`. No accounts yet.

### Task 1: Compose stack and empty Go server

**Files:**
- Create: `deploy/docker-compose.yml`
- Create: `services/api/Dockerfile`
- Create: `services/api/go.mod`
- Create: `services/api/cmd/api/main.go`
- Create: `services/api/internal/http/server.go`
- Test: `services/api/internal/http/server_test.go`

**Interfaces:**
- Consumes: none
- Produces: `GET /healthz` → `200` body `ok`. Listen addr from `ADDR` default `:8080`. DSN from `DATABASE_URL`.

- [ ] **Step 1: Write the failing test**

```go
func TestHealthz(t *testing.T) {
    req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
    rr := httptest.NewRecorder()
    NewServer(nil).Handler().ServeHTTP(rr, req)
    if rr.Code != 200 || rr.Body.String() != "ok" {
        t.Fatalf("got %d %q", rr.Code, rr.Body.String())
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/api && go test ./internal/http/ -count=1`
Expected: FAIL, `NewServer` undefined.

- [ ] **Step 3: Write minimal implementation**

`deploy/docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: knowmates
      POSTGRES_PASSWORD: knowmates
      POSTGRES_DB: knowmates
    ports: ["5432:5432"]
    volumes: ["pg:/var/lib/postgresql/data"]
  valkey:
    image: valkey/valkey:8-alpine
    ports: ["6379:6379"]
  api:
    build: ../services/api
    environment:
      ADDR: ":8080"
      DATABASE_URL: postgres://knowmates:knowmates@postgres:5432/knowmates?sslmode=disable
      REDIS_URL: redis://valkey:6379/0
      ASSET_DIR: /data/avatars
    ports: ["8080:8080"]
    depends_on: [postgres, valkey]
    volumes: ["avatars:/data/avatars"]
volumes:
  pg: {}
  avatars: {}
```

`services/api/Dockerfile`:

```dockerfile
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /api ./cmd/api

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=build /api /usr/local/bin/api
USER nobody
EXPOSE 8080
ENTRYPOINT ["api"]
```

Run `go mod tidy` in `services/api` before the first image build so `go.sum` exists. `server.go` returns a `http.ServeMux` with `/healthz`. `main.go` calls `ListenAndServe`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/api && go test ./... -count=1`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add deploy services/api
git commit -m "feat: add API healthcheck and local compose stack"
```

### Task 2: Flutter app, tokens, welcome screen

**Files:**
- Create: `apps/mobile/` via `flutter create`
- Create: `apps/mobile/lib/theme/app_colors.dart`
- Create: `apps/mobile/lib/theme/app_theme.dart`
- Create: `apps/mobile/lib/screens/welcome_screen.dart`
- Create: `apps/mobile/lib/main.dart`
- Test: `apps/mobile/test/widget_test.dart`

**Interfaces:**
- Consumes: `AppColors` from this task
- Produces: `WelcomeScreen` widget. Button key `get_started`. On press, calls `onGetStarted`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('welcome shows wordmark and get started', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: WelcomeScreen(onGetStarted: () {}),
  ));
  expect(find.text('Know'), findsOneWidget);
  expect(find.text('Mates'), findsOneWidget);
  expect(find.textContaining('Learn from people'), findsOneWidget);
  expect(find.byKey(const Key('get_started')), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/widget_test.dart`
Expected: FAIL, `WelcomeScreen` undefined.

- [ ] **Step 3: Write minimal implementation**

Create the app:

```bash
flutter create --org app.knowmates --project-name knowmates --platforms android apps/mobile
```

In the same task, set Android `namespace` and `applicationId` to `app.knowmates` so the package is not `app.knowmates.knowmates`.

`WelcomeScreen` is a `Scaffold` with `backgroundColor: AppColors.bg`. Column: wordmark row, `Expanded` with `GlobePainter` (circle, dotted stroke, six `CircleAvatar` initials placed with `Alignment` around the circle — no network images), arc caption, headline, gradient button. Safe area on. Text scale factor does not overflow at 1.3 (wrap the column in a `SingleChildScrollView` if the test surface is short). The tagline appears once, as the headline, so the widget test can find "Learn from people" with `findsOneWidget`. The arc uses the supporting line only.

`GlobePainter` draws a circle and a handful of lines. Initials `A`–`F` stand in for the mock's portraits.

Theme: `scaffoldBackgroundColor`, `fontFamily` the platform default, `colorScheme` seed unused — set explicit colors so Material widgets do not flash blue.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/mobile
git commit -m "feat: add the KnowMates welcome screen"
```

---

## Phase 1 — Authentication and profile (P0)

### Task 3: Users, passwords, age gate

**Files:**
- Create: `services/api/migrations/001_init.sql` (full script in Data model, including the starter-grant index)
- Create: `services/api/internal/auth/password.go`
- Create: `services/api/internal/store/store.go`
- Test: `services/api/internal/auth/password_test.go`
- Test: `services/api/internal/store/age_test.go`

**Interfaces:**
- Consumes: `DATABASE_URL`
- Produces:
  - `func Hash(password string) (string, error)`
  - `func Verify(hash, password string) (bool, error)`
  - `func AgeYears(birth time.Time, today time.Time) int`
  - `func (s *Store) CreateUser(ctx, email, hash string, birth time.Time, timezone string) (User, error)`
  - Argon2id parameters: time 1, memory 64 MiB, threads 2, salt 16 bytes, key 32 bytes. Encoded as the standard PHC string.

- [ ] **Step 1: Write the failing tests**

```go
func TestUnder18Rejected(t *testing.T) {
    birth := time.Date(2010, 1, 1, 0, 0, 0, 0, time.UTC)
    today := time.Date(2026, 10, 19, 0, 0, 0, 0, time.UTC)
    if AgeYears(birth, today) >= 18 {
        t.Fatal("expected under 18")
    }
}

func TestHashRoundTrip(t *testing.T) {
    h, err := Hash("correct horse battery")
    if err != nil {
        t.Fatal(err)
    }
    ok, err := Verify(h, "correct horse battery")
    if err != nil || !ok {
        t.Fatalf("verify failed %v %v", ok, err)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/api && go test ./internal/auth/ ./internal/store/ -count=1`
Expected: FAIL, undefined.

- [ ] **Step 3: Write minimal implementation**

`AgeYears` subtracts one if today's month-day is before the birthday.

`CreateUser` inserts and returns the row. `SignUp` handler calls `AgeYears` and responds `400 {"error":"underage"}` before any insert. Password minimum 10 characters. Email stored lowercase via `citext`.

Apply migration on startup with a tiny embedded runner: read `migrations/*.sql` in name order, record filename in `schema_migrations`. Do not add a migration framework.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/api && go test ./internal/auth/ ./internal/store/ -count=1`
Expected: PASS. Age test has no database. Store test uses `DATABASE_URL` or skips when unset — the compose test command below does not skip.

Run: `docker compose -f deploy/docker-compose.yml up -d postgres && cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test ./internal/store/ -count=1`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add services/api
git commit -m "feat: add accounts with argon2id and an 18+ age gate"
```

### Task 4: Access and refresh tokens

**Files:**
- Create: `services/api/internal/auth/tokens.go`
- Modify: `services/api/internal/http/server.go`
- Test: `services/api/internal/auth/tokens_test.go`

**Interfaces:**
- Consumes: `User.ID`, `AUTH_SECRET` (32+ bytes)
- Produces:
  - `func IssueAccess(secret []byte, userID uuid.UUID, now time.Time) (string, error)` TTL 15m, HMAC-SHA256 JWT, claims `sub`, `exp`
  - `func ParseAccess(secret []byte, raw string, now time.Time) (uuid.UUID, error)`
  - `func NewRefresh() (plain string, hash string)` 32 random bytes, hex plain, SHA-256 hash stored
  - Handler `POST /v1/auth/sign-up`, `POST /v1/auth/sign-in`, `POST /v1/auth/refresh`, `POST /v1/auth/sign-out`
  - Middleware `func WithUser(next)` puts `uuid.UUID` in context or 401

- [ ] **Step 1: Write the failing test**

```go
func TestAccessRoundTrip(t *testing.T) {
    id := uuid.New()
    raw, err := IssueAccess([]byte("0123456789abcdef0123456789abcdef"), id, time.Now())
    if err != nil {
        t.Fatal(err)
    }
    got, err := ParseAccess([]byte("0123456789abcdef0123456789abcdef"), raw, time.Now())
    if err != nil || got != id {
        t.Fatalf("got %v %v", got, err)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/api && go test ./internal/auth/ -count=1 -run TestAccessRoundTrip`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Sign-in verifies the PHC hash. Unknown email and bad password both return `401 {"error":"bad_credentials"}` so the handler does not reveal which emails exist. Rate limit in Valkey via `github.com/redis/go-redis/v9`: key `login:{ip}` INCR, EXPIRE 60, reject at 10 with `429`. Production points `REDIS_URL` at the Valkey container on the same VM.

Refresh stores `token_hash`. On refresh, revoke the presented row and insert a new one in the same transaction. Reuse of a revoked refresh revokes every refresh for that user (theft response) and returns 401.

Sign-out deletes only the presented refresh.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/api && go test ./... -count=1`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add services/api
git commit -m "feat: issue rotating refresh tokens and short-lived access tokens"
```

### Task 5: Profile, skills, availability, starter grant

**Files:**
- Modify: `services/api/internal/store/store.go`
- Modify: `services/api/internal/http/server.go`
- Create: `services/api/internal/avatar/store.go`
- Test: `services/api/internal/store/profile_test.go`
- Test: `services/api/internal/avatar/jpeg_test.go`

**Interfaces:**
- Consumes: `CreateUser`, ledger table
- Produces:
  - `func (s *Store) ReplaceSkills(ctx, userID uuid.UUID, teach, learn []SkillLevel) error`
  - `func (s *Store) ReplaceAvailability(ctx, userID uuid.UUID, slots []Slot) error`
  - `func (s *Store) MarkReady(ctx, userID uuid.UUID) error` sets `profile_ready` and inserts starter grant if the user has a display name, at least one teach skill, one learn skill, and one slot
  - `GET/PATCH /v1/me`, `PUT /v1/me/skills`, `PUT /v1/me/availability`
  - Seed skills in the migration: Web Development, Mobile Development, UI Design, Spanish, English Conversation, Interview Prep, Running. Stable UUIDs written in the SQL file.

- [ ] **Step 1: Write the failing test**

```go
func TestStarterGrantOnce(t *testing.T) {
    // create user, replace skills and one slot, MarkReady twice
    // balance == 2
}
```

Use a real Postgres from `DATABASE_URL`. Insert the assertion `if bal != 2 { t.Fatalf("balance %d", bal) }`.

```go
func TestFitJPEGCapsEdge(t *testing.T) {
    // encode a 1000x10 solid image with image/jpeg
    // out, err := FitJPEG(body, 512, 75)
    // decoded long edge <= 512, and out still decodes as JPEG
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/api && go test ./internal/avatar/ -count=1 -run TestFitJPEGCapsEdge`
Expected: FAIL

Run: `cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test ./internal/store/ -count=1 -run TestStarterGrantOnce`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

`MarkReady` runs in a transaction. The unique partial index makes the second grant insert a no-op via `ON CONFLICT DO NOTHING`. Balance query is `SELECT COALESCE(SUM(delta),0) FROM credit_ledger WHERE user_id=$1`.

Avatar handler rejects non-JPEG and bodies over 1 MiB, then stores a recompressed JPEG so 1 lakh photos fit on the free disk. `FitJPEG` decodes with `image/jpeg`, scales with nearest-neighbor so the long edge is at most 512, and encodes at quality 75. No new dependency. `AvatarStore.PutJPEG` writes those bytes and returns a URL stored on the user.

```go
func FitJPEG(body []byte, maxEdge int, quality int) ([]byte, error)

type AvatarStore interface {
    PutJPEG(ctx context.Context, userID uuid.UUID, body []byte) (url string, error)
}
```

`DiskStore` writes under `ASSET_DIR` and returns `PUBLIC_BASE + "/avatars/" + id + ".jpg"`. Caddy serves that directory. The API never proxies image bytes. `ponytail:` the 100 GB volume is the ceiling through 1 lakh users (about 20 GB of photos). R2's free 10 GB is for database dumps only, so avatars do not move there. Upgrade path when the volume passes 70 GB is a larger disk on the same Compose file.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test ./internal/store/ ./internal/avatar/ -count=1`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add services/api
git commit -m "feat: save skills profile and grant two starter credits once"
```

### Task 6: Phone auth and profile setup

**Files:**
- Create: `apps/mobile/lib/api/client.dart`
- Create: `apps/mobile/lib/auth/auth_controller.dart`
- Create: `apps/mobile/lib/router.dart`
- Create: `apps/mobile/lib/screens/sign_up_screen.dart`
- Create: `apps/mobile/lib/screens/sign_in_screen.dart`
- Create: `apps/mobile/lib/screens/setup_screen.dart`
- Modify: `apps/mobile/lib/main.dart`
- Test: `apps/mobile/test/widget_test.dart`

**Interfaces:**
- Consumes: API from Tasks 4 and 5. Base URL `--dart-define=API_BASE=http://10.0.2.2:8080` for the Android emulator.
- Produces: `AuthController` (`ChangeNotifier`) with `signUp`, `signIn`, `signOut`, `accessToken`. Tokens in `flutter_secure_storage`. Router redirects: no token → Welcome; token and not ready → Setup; ready → Home.

Dependencies to add, and no others: `go_router`, `http`, `flutter_secure_storage`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('sign up blocks a birth year that is under 18', (tester) async {
  await tester.pumpWidget(MaterialApp(home: SignUpScreen(onSubmit: (_) {})));
  await tester.enterText(find.byKey(const Key('birth')), '2010-01-01');
  await tester.tap(find.byKey(const Key('submit_sign_up')));
  await tester.pump();
  expect(find.text('You need to be 18 or older.'), findsOneWidget);
});
```

The widget checks age before calling `onSubmit`. Server remains the real gate.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/widget_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Form fields: email, password (10+), birth date `YYYY-MM-DD`, timezone default `DateTime.now().timeZoneName` is not an IANA name. Send a fixed list and default `Asia/Kolkata` when the device offset is `+05:30`, else `Etc/UTC`. The user can change it on the setup screen.

Setup screen three steps share one `PageView`: display name, languages (multi-select from `en`, `es`, `hi`), skills (two lists fed by `GET /v1/skills`), weekday hours. Last step calls skills, availability, then the server `MarkReady` via `PATCH /v1/me` with `{"ready":true}`.

Show API `underage` and `email_taken` as text under the button.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/mobile
git commit -m "feat: sign up, sign in, and finish a skills profile on device"
```

---

## Phase 2 — Discovery and matching (P0)

### Task 7: Score function and discover endpoint

**Files:**
- Create: `services/api/internal/match/score.go`
- Create: `services/api/internal/match/score_test.go`
- Modify: `services/api/internal/store/store.go`
- Modify: `services/api/internal/http/server.go`

**Interfaces:**
- Consumes: `Score(Input) int` as specified in Matching
- Produces: `GET /v1/discover?skillId=&language=&weekday=&cursor=` response

```json
{
  "people": [
    {
      "id": "uuid",
      "displayName": "string",
      "bio": "string",
      "languages": ["en"],
      "teach": [{"skillId": "uuid", "name": "Web Development", "proficiency": 4}],
      "sessionsTaught": 0,
      "ratingAvg": 0,
      "ratingCount": 0,
      "score": 70,
      "avatarUrl": ""
    }
  ],
  "nextCursor": ""
}
```

Cursor is the last `(score, id)` pair, base64 JSON. Empty when the page is short.

- [ ] **Step 1: Write the failing test**

```go
func TestScoreLanguageAndGap(t *testing.T) {
    got := Score(Input{LanguageMatch: true, OverlapMinutes: 120, ProficiencyGap: 2, RatingAvg: 5, RatingCount: 3})
    // 50 + 20 + 2 + 10 + 5
    if got != 87 {
        t.Fatalf("score %d", got)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/api && go test ./internal/match/ -count=1`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

SQL candidate query (parameters `$1` viewer, `$2` skill, limit 100). Teacher rating is the average of reviews written by the learner of that session:

```sql
SELECT u.id, u.display_name, u.bio, u.languages, u.avatar_path, u.timezone,
       us.proficiency,
       COALESCE(r.avg, 0), COALESCE(r.n, 0),
       COALESCE(st.n, 0)
FROM user_skills us
JOIN users u ON u.id = us.user_id
LEFT JOIN (
  SELECT s.teacher_id, AVG(rev.rating)::float8 AS avg, COUNT(*) AS n
  FROM reviews rev
  JOIN sessions s ON s.id = rev.session_id AND rev.reviewer_id = s.learner_id
  GROUP BY s.teacher_id
) r ON r.teacher_id = u.id
LEFT JOIN (
  SELECT teacher_id, COUNT(*) AS n
  FROM sessions
  WHERE status = 'completed'
  GROUP BY teacher_id
) st ON st.teacher_id = u.id
WHERE us.skill_id = $2 AND us.role = 'teach' AND u.profile_ready
  AND u.id <> $1
  AND NOT EXISTS (
    SELECT 1 FROM blocks b
    WHERE (b.blocker_id = $1 AND b.blocked_id = u.id)
       OR (b.blocker_id = u.id AND b.blocked_id = $1)
  )
LIMIT 100
```

Overlap minutes: load viewer slots and candidate slots for the returned ids in one `WHERE user_id = ANY($ids)` query. Convert both sides from their `timezone` to UTC minutes for the viewed weekday using `time.LoadLocation`. If a filter `weekday` is set, drop candidates with zero overlap that day. Language filter drops candidates whose `languages` does not contain the code. Language match for scoring is intersection with the viewer's languages.

Sort by `Score` desc, then id. Apply cursor. Cache the JSON in Valkey for 30s. If Valkey is down, serve Postgres (do not fail the request). Discover queries use `DATABASE_READ_URL` when set.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/api && go test ./internal/match/ ./internal/store/ -count=1`
Expected: PASS, including a store test with two teachers where the language-matching teacher ranks first.

- [ ] **Step 5: Commit**

```bash
git add services/api
git commit -m "feat: rank learning partners with a transparent score"
```

### Task 8: Discover and person screens

**Files:**
- Create: `apps/mobile/lib/screens/shell_screen.dart`
- Create: `apps/mobile/lib/screens/discover_screen.dart`
- Create: `apps/mobile/lib/screens/person_screen.dart`
- Create: `apps/mobile/lib/screens/home_screen.dart` (static shell filled in Task 12)
- Modify: `apps/mobile/lib/router.dart`
- Test: `apps/mobile/test/widget_test.dart`

**Interfaces:**
- Consumes: discover JSON from Task 7
- Produces: `DiscoverScreen(people:, onRequest:, onSkip:, onOpen:)`. Card shows name, bio, first two teach chips, languages, sessions taught, rating only when `ratingCount >= 3`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('discover card hides an unproven rating', (tester) async {
  await tester.pumpWidget(MaterialApp(home: DiscoverScreen(
    people: [
      Person(id: '1', displayName: 'Emma Thompson', bio: 'Customer service expert transitioning into tech.',
        languages: ['en', 'es'], teach: [TeachSkill(name: 'Web Development', proficiency: 4)],
        sessionsTaught: 28, ratingAvg: 4.9, ratingCount: 2, score: 80),
    ],
    onRequest: (_) {}, onSkip: (_) {}, onOpen: (_) {},
  )));
  expect(find.text('Emma Thompson'), findsOneWidget);
  expect(find.text('4.9'), findsNothing);
  expect(find.textContaining('Online'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/widget_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Card layout follows mock screen 2: rounded rectangle `AppColors.card`, 1 px `cardEdge`, avatar circle, name, bio, chips, large initial block (letter on magenta circle) in place of a portrait when `avatarUrl` is empty, three icon buttons. `ListView.builder`, one card per person, pull-to-refresh reloads. Filters as a horizontal chip row: skill (required, default the viewer's first learn skill), language, weekday.

Shell is a `NavigationBar` with five destinations. Home and the other tabs can render an empty scaffold until their tasks land. Center item uses a filled magenta circle behind the sparkle icon.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/mobile
git commit -m "feat: add discover cards and the five-tab shell"
```

---

## Phase 3 — Requests, sessions, ledger (P0)

### Task 9: Learning requests

**Files:**
- Modify: `services/api/internal/store/store.go`
- Modify: `services/api/internal/http/server.go`
- Test: `services/api/internal/store/request_test.go`

**Interfaces:**
- Consumes: users, skills, blocks
- Produces:
  - `func (s *Store) CreateRequest(ctx, learner, teacher, skill uuid.UUID, goal string) (Request, error)`
  - `func (s *Store) SetRequestStatus(ctx, id, actor uuid.UUID, to string) error`
  - Routes in the HTTP table

Rules: teacher must teach that skill; learner must not be blocked; only one `pending` row per `(learner, teacher, skill)`; teacher accepts or declines; learner cancels only `pending`; a second accept returns `conflict`.

- [ ] **Step 1: Write the failing test**

```go
func TestOnlyTeacherCanAccept(t *testing.T) {
    // learner SetRequestStatus accept → error forbidden
    // teacher SetRequestStatus accept → status accepted
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test ./internal/store/ -count=1 -run TestOnlyTeacherCanAccept`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Status changes are `UPDATE ... WHERE id=$1 AND status='pending' AND <actor column>=$2`. Zero rows → 409 `conflict`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test ./internal/store/ -count=1 -run TestOnlyTeacherCanAccept`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add services/api
git commit -m "feat: send, accept, decline, and cancel learning requests"
```

### Task 10: Schedule, hold, complete, release

**Files:**
- Create: `services/api/internal/credits/ledger.go`
- Create: `services/api/ledger_test.go`
- Modify: `services/api/internal/store/store.go`
- Modify: `services/api/internal/http/server.go`

**Interfaces:**
- Consumes: `credit_ledger`, `sessions`, accepted `swap_requests`
- Produces:
  - `func ValidMeetingURL(raw string) (string, error)` accepts an empty string, or an `https` URL of length 8–300 with no userinfo
  - `func (s *Store) Schedule(ctx, requestID, actor uuid.UUID, start, end time.Time, meetingURL string) (Session, error)`
  - `func (s *Store) Complete(ctx, sessionID, actor uuid.UUID) (status string, err error)`
  - `func (s *Store) CancelSession(ctx, sessionID, actor uuid.UUID) error`
  - `GET /v1/wallet`

- [ ] **Step 1: Write the failing test**

```go
func TestSettleIsIdempotent(t *testing.T) {
    // learner balance starts at 2
    // schedule → balance 1
    // complete as learner, then teacher → learner 1, teacher 1 (teacher had 2 starter, now 3)
    // complete again → balances unchanged
}
```

Teacher also received a starter grant in setup, so expected teacher balance is 3.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test . -count=1 -run TestSettleIsIdempotent`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

`Schedule` transaction:

1. Lock the request row `FOR UPDATE`. Require `status=accepted` and actor is learner or teacher.
2. Lock learner ledger by summing inside the transaction after `SELECT id FROM users WHERE id=$learner FOR UPDATE`.
3. If balance < 1, return `insufficient_credits`.
4. Insert session `scheduled`. Store a validated `meetingUrl`, or NULL when the field is empty. Insert ledger `-1 session_hold`.
5. A non-empty link that is not `https`, or that is shorter than 8 or longer than 300, or that has userinfo, returns `400 {"error":"bad_meeting_url"}`. An empty link is stored as NULL.

`Complete` sets `learner_done` or `teacher_done` for the actor. When both are true, set `completed` and insert teacher `+1 teach_completed` `ON CONFLICT DO NOTHING`.

`CancelSession` only from `scheduled`. Insert `+1 session_release` `ON CONFLICT DO NOTHING`, set `cancelled`.

Wallet returns balance and the latest 50 ledger rows (`reason`, `delta`, `createdAt`, `sessionId`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test . ./internal/... -count=1`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add services/api
git commit -m "feat: schedule sessions and settle an append-only credit ledger"
```

### Task 11: Requests, sessions, wallet on the phone

**Files:**
- Create: `apps/mobile/lib/screens/requests_screen.dart`
- Create: `apps/mobile/lib/screens/sessions_screen.dart`
- Create: `apps/mobile/lib/screens/wallet_screen.dart`
- Modify: `apps/mobile/lib/screens/person_screen.dart`
- Modify: `apps/mobile/lib/screens/home_screen.dart`
- Test: `apps/mobile/test/credit_copy_test.dart`

**Interfaces:**
- Consumes: request and session routes, `GET /v1/wallet`, `GET /v1/me` which includes `balance`, `sessionsCompleted`, `teachCount`, `learnCount`
- Produces: Home stat tiles bound to those four numbers. Wallet lists ledger reasons in plain language: "Starter credits", "Session booked", "Session cancelled", "Taught a session".

- [ ] **Step 1: Write the failing test**

```dart
test('ledger reason copy', () {
  expect(ledgerLabel('starter_grant'), 'Starter credits');
  expect(ledgerLabel('session_hold'), 'Session booked');
  expect(ledgerLabel('session_release'), 'Session cancelled');
  expect(ledgerLabel('teach_completed'), 'Taught a session');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/credit_copy_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Person screen: goal text field and "Request session" posting `/v1/requests`.

Requests tab: two sections, Incoming and Sent. Accept and Decline on incoming pending rows.

Sessions tab: datetime pickers in local time, converted to UTC ISO-8601 before POST, plus an optional backup-link field. When the stored URL is non-empty, show "Open backup link" with `url_launcher`. `url_launcher` is the one extra dependency in this task. Complete button per session. Cancel button while scheduled. The Join button is added in Task 15.

Home (mock screen 3 structure):

- Top row: refresh reloads `/v1/me`, "Welcome back,", bell icon hidden (no notification inbox in P0).
- Headline and subline from the Screens section.
- Orb painter, 180 logical pixels.
- 2×2 grid: Sessions = `sessionsCompleted`, Time Tokens = `balance`, Teaching = count of teach skills, Learning = count of learn skills. The mock shows `1.0` and `0.0`; we show integers because a fractional skill count would be fiction.
- Bottom card: first learn skill name, "{n} sessions", rating text "New" or "{avg}/5".

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/mobile
git commit -m "feat: show requests, sessions, wallet, and the home dashboard"
```

---

## Phase 4 — Trust, safety, account deletion (P0)

### Task 12: Block, report, delete

**Files:**
- Modify: `services/api/internal/store/store.go`
- Modify: `services/api/internal/http/server.go`
- Test: `services/api/internal/store/safety_test.go`

**Interfaces:**
- Consumes: blocks table, reports table
- Produces:
  - `POST /v1/blocks`, `DELETE /v1/blocks/{id}`, `POST /v1/reports`, `DELETE /v1/me`
  - `func (s *Store) DeleteUser(ctx, userID uuid.UUID) error`

Delete behavior: in one transaction, delete that user's `session_messages`, refresh tokens, ledger rows, reviews authored, blocks, reports filed, availability, and skills. Sessions the user taught or attended stay, with `learner_id` or `teacher_id` left intact so the other person's history remains — so we do **not** hard-delete a user who still has sessions. Instead: set `email` to `deleted-{id}@invalid`, `password_hash` to `!`, `display_name` to `Deleted member`, clear bio, languages, avatar file, `profile_ready=false`, and revoke refreshes. The other person's lines in that call stay. That satisfies Play account deletion (credentials, profile, and their chat text gone) and keeps the ledger honest.

If the user has zero sessions and zero ledger rows besides starter grant, hard-delete is allowed. Implement only the anonymize path. One path is enough.

- [ ] **Step 1: Write the failing test**

```go
func TestBlockedTeacherHidden(t *testing.T) {
    // after block, discover for that skill does not return the teacher
}

func TestDeleteRevokesLogin(t *testing.T) {
    // DeleteUser then sign-in returns bad_credentials
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test ./internal/store/ -count=1 -run 'TestBlockedTeacherHidden|TestDeleteRevokesLogin'`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Report insert does not require the target to confirm. When `sessionId` is set and the session is `scheduled` and the reporter is a participant, also set session `disputed` and write `session_release` so the hold returns. A report on a completed session only stores the report.

Person screen overflow menu: Block, Report. Profile screen: Delete account, with a typed confirmation `DELETE`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test ./... -count=1`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add services/api apps/mobile
git commit -m "feat: block, report, and anonymize deleted accounts"
```

### Task 13: Reviews

**Files:**
- Modify: `services/api/internal/http/server.go`
- Modify: `apps/mobile/lib/screens/sessions_screen.dart`
- Test: `services/api/internal/store/review_test.go`

**Interfaces:**
- Consumes: completed sessions
- Produces: `POST /v1/sessions/{id}/reviews` body `{rating, body}`. One review per participant. Rating appears in discover only after 3 learner reviews, already encoded in `Score`.

- [ ] **Step 1: Write the failing test**

Assert a review on a `scheduled` session returns `conflict`, and a second review by the same user returns `conflict`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test ./internal/store/ -count=1 -run TestReview`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Insert only when `sessions.status='completed'` and `reviewer_id` is the learner or the teacher. Unique constraint maps to `409 conflict`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test ./internal/store/ -count=1 -run TestReview`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add services/api apps/mobile
git commit -m "feat: review a completed session once"
```

---

## Phase 5 — In-app session call (P0)

### Task 14: Call admission, TURN ticket, and signaling

**Files:**
- Create: `services/api/internal/call/join.go`
- Create: `services/api/internal/call/turn.go`
- Create: `services/api/internal/call/signal.go`
- Create: `services/api/internal/call/call_test.go`
- Modify: `services/api/internal/store/store.go`
- Modify: `services/api/internal/http/server.go`

**Interfaces:**
- Consumes: `sessions`, `session_messages`, Valkey, `TURN_SECRET`, `TURN_URLS`
- Produces:
  - `func CanJoin(now time.Time, status string, starts time.Time) bool`
  - `func TurnCreds(secret string, userID uuid.UUID, now time.Time) (username, password string, expiry time.Time)`
  - `POST /v1/sessions/{id}/call/ticket`
  - `GET /v1/sessions/{id}/call` WebSocket, protocol in the Call section
  - `func (s *Store) InsertCallMessage(ctx, sessionID, sender uuid.UUID, body string) (id uuid.UUID, created time.Time, err error)`
  - `func (s *Store) CallHistory(ctx, sessionID uuid.UUID) ([]CallMessage, error)` latest 100, oldest first

- [ ] **Step 1: Write the failing test**

```go
func TestCanJoinWindow(t *testing.T) {
    start := time.Date(2026, 10, 19, 12, 0, 0, 0, time.UTC)
    if CanJoin(start.Add(-11*time.Minute), "scheduled", start) {
        t.Fatal("11 minutes early")
    }
    if !CanJoin(start.Add(-9*time.Minute), "scheduled", start) {
        t.Fatal("9 minutes early should open")
    }
    if !CanJoin(start.Add(2*time.Hour), "scheduled", start) {
        t.Fatal("past ends_at stays open while scheduled")
    }
    for _, status := range []string{"cancelled", "completed", "disputed"} {
        if CanJoin(start, status, start) {
            t.Fatal(status)
        }
    }
}

func TestTurnCredsMatchCoturnREST(t *testing.T) {
    id := uuid.MustParse("11111111-1111-1111-1111-111111111111")
    now := time.Unix(1_700_000_000, 0).UTC()
    user, pass, exp := TurnCreds("test-secret", id, now)
    if exp.Sub(now) != time.Hour {
        t.Fatalf("ttl %s", exp.Sub(now))
    }
    if user != strconv.FormatInt(exp.Unix(), 10)+":"+id.String() {
        t.Fatalf("username %s", user)
    }
    mac := hmac.New(sha1.New, []byte("test-secret"))
    mac.Write([]byte(user))
    want := base64.StdEncoding.EncodeToString(mac.Sum(nil))
    if pass != want {
        t.Fatalf("password %s", pass)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/api && go test ./internal/call/ -count=1`
Expected: FAIL with `CanJoin` undefined

- [ ] **Step 3: Write minimal implementation**

```go
func CanJoin(now time.Time, status string, starts time.Time) bool {
    if status != "scheduled" {
        return false
    }
    return !now.Before(starts.Add(-10 * time.Minute))
}

func TurnCreds(secret string, userID uuid.UUID, now time.Time) (string, string, time.Time) {
    exp := now.UTC().Add(time.Hour).Truncate(time.Second)
    username := strconv.FormatInt(exp.Unix(), 10) + ":" + userID.String()
    mac := hmac.New(sha1.New, []byte(secret))
    mac.Write([]byte(username))
    return username, base64.StdEncoding.EncodeToString(mac.Sum(nil)), exp
}
```

Ticket handler: the caller is the learner or the teacher, and `CanJoin` is true, else `403 {"error":"call_closed"}` for a participant outside the window and `403 {"error":"forbidden"}` for anyone else. `stun` is always `["stun:stun.cloudflare.com:3478"]`. When `TURN_SECRET` is empty, `turn` is `[]` and `username` and `password` are empty. Otherwise `turn` is the comma-separated `TURN_URLS` and the password comes from `TurnCreds`.

WebSocket, after the same admission check: subscribe to Valkey `call:{sessionID}` with a connection that is closed when the socket closes. Publish `{"type":"peer","from":"<userID>","joined":true}`, send `history`, then read client frames.

- `offer`, `answer`, `ice`, `share`, `hangup`: add `from` and publish. Forward to this socket only when the published `from` is the other user.
- `chat`: reject a body outside 1–500 with a close. `INCR` `chat:{sessionID}:{userID}` and `EXPIRE` 60 on the first hit. Above 30, send `{"type":"error","error":"chat_limited"}` and do not insert. Otherwise insert, then publish `{"type":"chat","id","from","body","createdAt"}`.
- On disconnect, publish `joined:false`.

The server never builds SDP. `go-redis` is already the Valkey client used for the discover cache. The WebSocket library is `coder/websocket`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test ./internal/call/ ./internal/store/ -count=1`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add services/api
git commit -m "feat: admit a session call and forward its handshake through Valkey"
```

### Task 15: Call screen on the phone

**Files:**
- Create: `apps/mobile/lib/call/join_window.dart`
- Create: `apps/mobile/lib/screens/call_screen.dart`
- Modify: `apps/mobile/lib/screens/sessions_screen.dart`
- Modify: `apps/mobile/lib/router.dart`
- Modify: `apps/mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `apps/mobile/pubspec.yaml`
- Test: `apps/mobile/test/join_window_test.dart`

**Interfaces:**
- Consumes: `CanJoin` rules, ticket JSON, WebSocket frames from Task 14
- Produces: `bool canJoin(DateTime now, String status, DateTime starts)` and `CallScreen` opened from a session row

- [ ] **Step 1: Write the failing test**

```dart
test('join opens ten minutes before start', () {
  final start = DateTime.utc(2026, 10, 19, 12);
  expect(canJoin(start.subtract(const Duration(minutes: 11)), 'scheduled', start), isFalse);
  expect(canJoin(start.subtract(const Duration(minutes: 9)), 'scheduled', start), isTrue);
  expect(canJoin(start.add(const Duration(hours: 2)), 'scheduled', start), isTrue);
  expect(canJoin(start, 'cancelled', start), isFalse);
  expect(canJoin(start, 'disputed', start), isFalse);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/join_window_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

`canJoin` is the same rule as `CanJoin`: status is `scheduled`, and `now` is not before `starts` minus 10 minutes.

`pubspec.yaml` adds `flutter_webrtc`. Signaling uses `WebSocket` from `dart:io` against `wss://<host>/v1/sessions/<id>/call` with the bearer access token. That is the second and last extra dependency after `url_launcher`.

Android manifest permissions: `CAMERA`, `RECORD_AUDIO`, `INTERNET`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`. `flutter_webrtc`'s screen-share service is the foreground service. No other SDK.

Session row: "Join" when `canJoin` is true, opening `CallScreen(sessionId)`. "Open backup link" only when `meetingUrl` is non-empty.

`CallScreen`:

- Background `AppColors.bg`. Remote video fills the screen. Before it arrives, the line is "Waiting for your mate."
- Local preview sits bottom-left, 96 by 144.
- Buttons: mute microphone, turn camera off, share screen, open chat, hang up.
- On open, request camera and microphone. A denial shows "KnowMates needs the camera and microphone for this session." and a back button.
- Fetch the ticket, then `createPeerConnection` with the stun and turn URLs. `iceTransportPolicy` stays `all`, so a direct path wins.
- After the peer frame says the other person joined, the teacher calls `createOffer`. The learner sets the remote offer and sends `answer`. Each side sends its ICE candidates as `ice` frames.
- The camera video sender's `maxBitrate` is 500000. Share screen calls `getDisplayMedia`, `replaceTrack` on that sender, and sets `maxBitrate` 800000. "Stop sharing" puts the camera track back. One outbound video track at a time.
- Chat panel lists `history` then live `chat` frames. The field submits a `chat` frame and refuses a body over 500 characters. Own lines sit on the right.
- Hang up sends `hangup` and pops the route. It does not call complete or cancel.
- A `call_closed` or socket error shows "This session is not open for a call." with the backup link underneath when one is stored.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/mobile
git commit -m "feat: join a booked session with camera, screen share, and chat"
```

---

## Phase 6 — Free production VM and Play internal testing

### Task 16: SMTP email gate and the Mumbai VM

**Files:**
- Create: `services/api/internal/mail/mail.go`
- Create: `services/api/migrations/002_verify.sql`
- Create: `docs/privacy-policy.html`
- Create: `deploy/Caddyfile`
- Create: `deploy/docker-compose.prod.yml`
- Create: `deploy/backup.sh`
- Create: `deploy/.env.example`
- Modify: `services/api/internal/http/server.go`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: a domain on Cloudflare's free plan, a Brevo free SMTP account, an Oracle Always Free Ampere VM
- Produces:
  - `type Sender interface { Send(ctx context.Context, to, subject, text string) error }`
  - `LogSender` when `SMTP_HOST` is empty
  - `SMTPSender` using `net/smtp` with STARTTLS when `SMTP_HOST` is set
  - `https://api.<domain>/healthz` returns `ok` from the VM

Email verification: sign-up stores `email_verified=false` and asks `Sender` to mail a 24-hour link `https://<PUBLIC_HOST>/v1/auth/verify?token=`. Discovery returns 403 `email_unverified` until the flag is true. `POST /v1/auth/verify/resend` is limited to once per 10 minutes with Valkey key `verify:{userID}`. Sign-up still succeeds if SMTP returns an error; the user can resend. Laptop tests inject `LogSender` and never open a network connection.

`SMTP_FROM` is the bare verified address, `hello@<domain>`. Brevo's free tier is 300 messages a day. Confirm that number on the day the account is created. A day over the cap changes `SMTP_HOST`, `SMTP_USER`, and `SMTP_PASSWORD` only.

Privacy policy states: account email, profile, avatar, skills, availability, session times, optional backup meeting links, session chat text, wallet entries, device push token, reports. Audio and video of a call go between the two phones. KnowMates stores the chat text and does not record the call. Purpose is running exchanges. Contact email. Users delete the account inside Profile, which also deletes chat lines they sent. No sale of data. No advertising SDK. Camera and microphone are requested only after Join. Caddy serves the page at `https://api.<domain>/privacy`.

VM, created by hand in the Oracle console (there is no Terraform):

- Home region Mumbai (`ap-mumbai-1`). Shape `VM.Standard.A1.Flex`, Ubuntu 24.04 aarch64, 2 OCPU, 12 GB RAM, 100 GB boot volume. Leave the rest of the always-free quota unused.
- Security list: TCP 22 from the operator IP only, TCP 80 and 443 from `0.0.0.0/0`, TCP and UDP 3478 from `0.0.0.0/0`, UDP 49160–49200 from `0.0.0.0/0`. Do not open 5432 or 6379.
- Install Docker and the compose plugin. Clone the repo to `/opt/knowmates`. `.env` is mode `600`.
- Cloudflare: proxied A record `api` to the VM's public IP, SSL mode Full (strict), origin certificate for `api.<domain>` stored in `deploy/certs/` (gitignored). Grey-cloud A record `turn` to the same public IP. Do not proxy `turn`.
- Brevo: verify the domain with the DNS records Cloudflare shows, put the SMTP key in `.env`.
- Cloudflare R2 bucket `knowmates-backups` (free tier) and an `rclone` remote named in `RCLONE_REMOTE`. Set this before any real account exists.
- `docker compose -f deploy/docker-compose.prod.yml up -d --build`, then `curl https://api.<domain>/healthz` prints `ok`.
- Cron `15 3 * * * /opt/knowmates/deploy/backup.sh`.

- [ ] **Step 1: Write the failing test**

```go
func TestDiscoverRequiresVerifiedEmail(t *testing.T) {
    // user with email_verified=false calls GET /v1/discover
    // response 403 and body {"error":"email_unverified"}
}
```

Add the assertion against the handler, with `email_verified` defaulting to false on insert. Migration file `services/api/migrations/002_verify.sql`:

```sql
ALTER TABLE users ADD COLUMN email_verified boolean NOT NULL DEFAULT false;
CREATE TABLE email_tokens (
  token_hash text PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES users(id),
  expires_at timestamptz NOT NULL
);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test ./internal/http/ -count=1 -run TestDiscoverRequiresVerifiedEmail`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Discover handler returns 403 `email_unverified` when the flag is false. `POST /v1/auth/verify/resend` writes a random token, stores its SHA-256, and calls `Sender.Send`. Link is `https://<PUBLIC_HOST>/v1/auth/verify?token=<plain>`. `GET /v1/auth/verify` sets `email_verified=true` and deletes the token. Valkey key `verify:{userID}` blocks a second resend for 10 minutes. Sign-in of an unverified user still returns tokens so they can open the app and resend. The unit test uses a `Sender` double and asserts `Send` was called once.

`SMTPSender.Send` dials `SMTP_HOST:SMTP_PORT` (587), `StartTLS` with `ServerName` set to that host, then `PlainAuth`. Envelope sender is the bare `SMTP_FROM`. The header is `From: KnowMates <SMTP_FROM>`. `SenderFromEnv` returns `LogSender` when `SMTP_HOST` is empty. Standard library only: `net/smtp`, `crypto/tls`.

`deploy/docker-compose.prod.yml` publishes 80 and 443 on Caddy. coturn uses the host network so relayed candidates advertise the VM address. The API environment overrides `DATABASE_URL` so it cannot drift from `POSTGRES_PASSWORD`:

```yaml
services:
  caddy:
    image: caddy:2-alpine
    ports: ["80:80", "443:443"]
    environment:
      API_HOST: ${API_HOST}
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./certs:/etc/caddy/certs:ro
      - caddy:/data
      - avatars:/srv/avatars:ro
      - ../docs/privacy-policy.html:/srv/privacy.html:ro
    depends_on: [api]
    restart: unless-stopped
  api:
    build: ../services/api
    env_file: ../.env
    environment:
      DATABASE_URL: postgres://knowmates:${POSTGRES_PASSWORD}@postgres:5432/knowmates?sslmode=disable
      REDIS_URL: redis://valkey:6379/0
      ASSET_DIR: /data/avatars
      TURN_SECRET: ${TURN_SECRET}
      TURN_URLS: ${TURN_URLS}
    volumes: ["avatars:/data/avatars", "./secrets:/secrets:ro"]
    depends_on: [postgres, valkey]
    restart: unless-stopped
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: knowmates
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: knowmates
    volumes: ["pg:/var/lib/postgresql/data"]
    restart: unless-stopped
  valkey:
    image: valkey/valkey:8-alpine
    volumes: ["valkey:/data"]
    restart: unless-stopped
  coturn:
    image: coturn/coturn:4.18.0
    network_mode: host
    restart: unless-stopped
    command:
      - --listening-port=3478
      - --fingerprint
      - --use-auth-secret
      - --static-auth-secret=${TURN_SECRET}
      - --realm=knowmates
      - --total-quota=40
      - --max-bps=800000
      - --stale-nonce=600
      - --no-multicast-peers
      - --no-cli
      - --min-port=49160
      - --max-port=49200
      - --external-ip=${TURN_PUBLIC_IP}/${TURN_PRIVATE_IP}
volumes:
  pg: {}
  valkey: {}
  avatars: {}
  caddy: {}
```

`deploy/Caddyfile`:

```
{$API_HOST} {
	tls /etc/caddy/certs/origin.pem /etc/caddy/certs/origin.key
	handle /avatars/* {
		root * /srv
		file_server
	}
	handle /privacy {
		root * /srv
		rewrite * /privacy.html
		file_server
	}
	handle {
		reverse_proxy api:8080
	}
}
```

`deploy/backup.sh`:

```sh
#!/bin/sh
set -eu
stamp=$(date +%F)
out="/var/backups/knowmates-$stamp.sql.gz"
mkdir -p /var/backups
docker compose -f /opt/knowmates/deploy/docker-compose.prod.yml exec -T postgres \
  pg_dump -U knowmates knowmates | gzip > "$out"
find /var/backups -name 'knowmates-*.sql.gz' -mtime +7 -delete
if [ -n "${RCLONE_REMOTE:-}" ]; then
  rclone copy "$out" "$RCLONE_REMOTE"
fi
```

`deploy/.env.example` names `POSTGRES_PASSWORD`, `API_HOST`, `AUTH_SECRET`, `PUBLIC_BASE`, `PUBLIC_HOST`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`, `FCM_CREDENTIALS_FILE`, `RCLONE_REMOTE`, `TURN_SECRET`, `TURN_PUBLIC_IP`, `TURN_PRIVATE_IP`, and `TURN_URLS`, with empty values. `TURN_URLS` is `turn:turn.<domain>:3478?transport=udp,turn:turn.<domain>:3478?transport=tcp`. `TURN_PRIVATE_IP` is the VM's VNIC address, the one `hostname -I` prints. `.gitignore` includes `.env`, `deploy/certs/`, and `*-service-account.json`. `docs/privacy-policy.html` is one page with the facts listed above and a contact address.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/api && DATABASE_URL=postgres://knowmates:knowmates@localhost:5432/knowmates?sslmode=disable go test ./... -count=1`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add services/api deploy docs/privacy-policy.html .gitignore
git commit -m "feat: verify email over SMTP and run production on the free VM"
```

### Task 17: Android release build and internal testing

**Files:**
- Modify: `apps/mobile/android/app/build.gradle.kts` (`applicationId`, minify)
- Create: `apps/mobile/android/app/src/main/AndroidManifest.xml` entries only as required below
- Create: `services/api/internal/push/push.go`
- Create: `services/api/migrations/003_devices.sql`
- Modify: Play Console listing copy in `docs/play-listing.md`

**Interfaces:**
- Consumes: a Google Play Console account. Registration is a one-time $25. There is no monthly cloud bill.
- Produces: an `.aab` on the internal testing track.

Manifest and Gradle:

- `applicationId` is `app.knowmates`. It was set in Task 2. Do not change it after this upload.
- `minSdk` 24. `targetSdk` is the Play target API required on the upload date (35 or whatever Play Console shows that week).
- `compileSdk` matches `targetSdk`.
- Internet permission only. Avatar uses the Android photo picker (`image_picker` is rejected — use `file_selector` or the framework image picker that does not request `READ_MEDIA_IMAGES`). Prefer no new dependency: an `Image.file` from `file_selector` if added, otherwise skip gallery and accept a JPEG the setup screen obtains via `file_selector`. One dependency `file_selector` is allowed here.
- `android:allowBackup="false"`.
- Release build uses Play App Signing. Generate the upload keystore locally. Do not commit it. `key.properties` is gitignored.

Push stays on the free FCM HTTP v1 API. The app collects an FCM token with `firebase_messaging` and posts it to `POST /v1/me/device`. Migration `services/api/migrations/003_devices.sql`:

```sql
CREATE TABLE device_tokens (
  user_id    uuid NOT NULL REFERENCES users(id),
  token      text PRIMARY KEY,
  updated_at timestamptz NOT NULL DEFAULT now()
);
```

The handler upserts that row. There is no SNS endpoint. `internal/push.Pusher` is `Send(ctx, token, title, body string) error`. When `FCM_CREDENTIALS_FILE` is empty, a log pusher is used and scheduling still succeeds. When it is set, the API uses `golang.org/x/oauth2/google` with scope `https://www.googleapis.com/auth/firebase.messaging` and POSTs to `https://fcm.googleapis.com/v1/projects/{project}/messages:send`. A push error is logged and does not fail the request or the session. The sessions tab remains the source of truth if a push is delayed. Gitignore `google-services.json` and `*-service-account.json`. The Firebase project stays on the Spark plan. Enable Cloud Messaging only. Do not enable Auth, Firestore, or Functions, and do not upgrade to Blaze. The service-account JSON is a secret.

Listing:

- Title: KnowMates.
- Short description: "Learn from people. Grow together."
- Full description: "KnowMates is a community where everyone has something to teach and something to learn. Find a person for coding, languages, design, cooking, photography, music, and more. Teach to earn time credits, then use them to learn from someone else. Join the session in the app, with video and screen share."
- Category: Education.
- Content rating: questionnaire answered for user interaction, yes; users can interact; no sexual content; no gambling. Age gate 18+ in the store listing and in the app.
- Data safety form matches the privacy policy. Declare camera and microphone as collected for the session call and not stored. Declare the session chat text as stored until the sender deletes their account.
- Ads: no.
- Screenshots: capture Welcome, Discover, Home, Session, and the call screen on a phone emulator. 1080×1920 minimum. These are your own screens, not the Dribbble image.

Build:

```bash
cd apps/mobile
flutter build appbundle --release --dart-define=API_BASE=https://<host>
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Internal testing. Add the tester Google accounts. Install from the Play opt-in link onto a physical Android phone.

Manual script on that phone, all must pass before calling P0 done:

1. Sign up with a birth date under 18 is rejected.
2. Sign up as an adult, finish profile, wallet shows 2.
3. Second account teaches the first account's learn skill.
4. Discover shows the teacher. Request, accept, schedule with no link. Learner balance becomes 1. On a second booking, paste an `https` link. "Open backup link" opens the browser. The first session shows no backup button.
5. Both phones, on different networks, tap Join inside the window. Each sees and hears the other. One shares the screen and the other sees it. One sends a chat line, force-closes the app, joins again, and the line is still there. Hang up. The session is still scheduled and the learner balance is still 1.
6. Both mark complete. Teacher balance becomes 3. Retrying complete does not change balances.
7. Cancel path on a second session returns the credit.
8. Block hides the person from discover.
9. Report a scheduled session and see the credit return.
10. Delete account. Sign-in fails. A chat line that account sent is gone for the other person.
11. Airplane mode shows a readable error, not a blank screen.

- [ ] **Step 1–5:** The release checklist above is the task. Commit listing docs and gradle pins only. Do not commit the keystore or `google-services.json` if it contains project identifiers you would rather inject at build time; `google-services.json` for an Android app is not a secret server key, but the service-account JSON is. Gitignore `*-service-account.json` and `key.properties`.

```bash
git add apps/mobile/android services/api docs/play-listing.md .gitignore
git commit -m "chore: pin the Android release build for Play internal testing"
```

---

## Later plans (do not build during P0)

Each one starts only after the internal-testing script is green. Each gets its own plan file when it starts. The contracts below are fixed so P0 does not paint itself into a corner.

### P1 Learning plans — `docs/superpowers/plans/` when started

Tables `sprints` (`id`, `learner_id`, `skill_id`, `goal`, `deadline`, `status`) and `milestones` (`sprint_id`, `position`, `title`, `exercise`, `done`). The learner writes milestones in the app. No model call. A session can optionally point at `sprint_id`. Done when a learner can check off milestones and see them on Home.

### P1 Messaging

Table `messages` (`id`, `request_id`, `sender_id`, `body`, `created_at`). Only the two people on an accepted request can read or write. Poll `GET /v1/requests/{id}/messages?after=` every 5 seconds while the thread is open. This is the inbox between requests. It is a different table from `session_messages`, which is the text inside a call. `ponytail:` polling is the ceiling; upgrade path is to reuse the session-call socket pattern on this table.

### P1 Portfolio

Table `portfolio_items` (`user_id`, `title`, `url`, `session_id` nullable, `visible bool`). Default `visible=false`. Public profile shows only `visible=true`.

### P2 Groups

Out of scope until one-to-one completion is the normal path. A circle is a later table, not a column stuffed onto `sessions`.

### P2 Ranking from outcomes

Replace nothing in the request path until it exists. Add `completion_rate` to `Score` as `+ up to 10` once a teacher has 5 completed sessions. Same function, new field, new test.

---

## What P0 deliberately leaves out

- Payments, payouts, and paid boosts.
- Call recording, and calls with more than two people.
- A generated curriculum model.
- Group circles.
- A second machine. Launch is one Mumbai VM. Another VM is the same compose file, after this one is carrying real exchanges.
- Presence dots and a games tab.

## Self-review

- Spec P0 items map to Tasks 3–17. P1/P2 are named and deferred with a contract.
- Credit reasons are the same four strings in SQL, Go tests, and `ledgerLabel`.
- Discover rating SQL uses learner-authored reviews. The score test expects 87 for the documented inputs.
- Under-18 is rejected in the client widget and again in `SignUp`.
- Account deletion is anonymize, specified in Task 12, because a hard delete breaks the other person's ledger. Chat lines that user sent are deleted with the account.
- The session call is Tasks 14 and 15. `CanJoin` and `canJoin` use the same window. TURN credentials are the coturn REST HMAC. Media is phone-to-phone, with coturn on the VM for the calls that cannot connect directly. An empty backup link is valid.
- Production is one always-free Mumbai VM, sized in the Cloud section. Laptop Compose runs Postgres and Valkey. Production Compose adds Caddy and coturn. Monthly infrastructure cost is $0 through 1 lakh registered users. The domain and the Play registration fee are the only cash costs, and the Play fee is stated in Task 17.
- Free-tier ceilings are named: Brevo 300 emails a day, R2 10 GB for dumps, avatars recompressed onto the VM disk, 10 TB outbound including relayed calls, 40 coturn allocations, second API VM still inside the Ampere quota. Past that, change a host or add a VM. Do not add a paid platform service in P0.
