# PharmaPath — Initial Audit (Phase 1–2)

Date: 2026-10-24
Auditor: OpenCode session on `/home/sifat/Desktop/PharmaPath`

## 1. What actually exists

| Location | Contents | Framework |
|---|---|---|
| `MedEx/` | Extracted APK payloads for MedEx 3.5.0 (`base.apk`, `config.*.apk`, manifest) | **Android app artifacts — no source code** |
| `MedEx.xapk` | Original split-APK bundle, untouched | Android |
| `MedEx-Reverse-Engineering/` | 12 reports + 625 recovered files + string/path evidence | Documentation only |
| `pharmapath_app/` | Flutter client built earlier in this session from the recovered API study | Flutter 3.47.7 / Dart 3.13.5 |

There is **no existing Flutter source project inside `MedEx/`**. The only source
codebase is `pharmapath_app/`, which currently targets the MedEx API and requires
an account token. The master plan's instruction to "open `MedEx/` and transform
it" therefore resolves to extending `pharmapath_app/`; the original artifacts
remain read-only and are not modified or redistributed.

## 2. Current PharmaPath v1 state

Working (verified earlier):

* `flutter analyze` clean, 10 unit tests passing, release web build, debug APK.
* Live catalogue browsing against `https://medex.com.bd/api/beta/` — **but the
  API rejects anonymous traffic** (`Authentication token missing`; invalid
  tokens return `Invalid token [IT900]`). The bearer header is confirmed.
* Offline demo fixtures, favourites/history in `get_storage`, HTML detail view.

Gaps versus the new master plan:

* No SQLite/offline database, no FTS search, no data provenance metadata.
* English UI; no Bangla typography.
* No learning academy, no quizzes, no progress tracking.
* No AI configuration or AI service.
* No backup/restore, no sync service.
* MedEx catalogue cannot be populated without a token, so it cannot seed an
  offline database lawfully.

## 3. New primary data source — verified from source

Repository: `NasirSunny50/Bangladeshi-Medicine-API` (default branch `main`).

Observed from `app/api.py` and `app/db.py` (not guessed):

| Route | Response shape |
|---|---|
| `GET /medicines?search=&company=&generic=&dosage_form=&page=&limit=` | `{page, limit, total, total_pages, results:[summary]}` |
| `GET /medicines/{id}` | full row incl. `sections` map |
| `GET /generics?search=&page=&limit=` | `{page, limit, results:[{generic_name, generic_id, brand_count}]}` |
| `GET /companies?...` | same shape with `company`, `company_id` |
| `GET /stats` | totals + last crawl run |
| `GET /health` | `{status: ok}` |

Medicine fields: `id, slug, url, brand_name, dosage_form, strength,
generic_name, generic_id, company, company_id, unit_price, price_text,
pack_sizes, indications, composition, pharmacology,
dosage_and_administration, interaction, contraindications, side_effects,
pregnancy_and_lactation, precautions_and_warnings, overdose_effects,
therapeutic_class, storage_conditions, common_questions, sections_json`.

Important properties:

* It is **not a hosted API**. You must run `uvicorn app.api:app` yourself after
  crawling; the database (`data/medex.db`) is git-ignored and empty on clone.
* The crawler scrapes `medex.com.bd` through a real browser session and the repo
  explicitly asks users to respect MedEx's servers.
* The repository has **no license file** (`license: null` via GitHub API) and its
  data is derived from MedEx. Therefore: no bundled data, no redistribution,
  integration stays configurable, and the app must show attribution/verification
  status. Commercial/public deployment requires written permission.

## 4. Risks

1. **Licensing** — data provenance is MedEx; no license. Personal/local use only
   until permission is obtained.
2. **No API availability** — without a self-hosted server the app must remain
   fully usable offline with whatever was synced previously.
3. **Field completeness** — listing rows are summaries; clinical sections arrive
   only from `/medicines/{id}`. Detail is fetched lazily and cached.
4. **Cleartext HTTP** — local dev server is HTTP; Android must allow cleartext
   only for loopback/emulator hosts.
5. **AI key on device** — a user-provided DeepSeek key is extractable on a
   compromised device; a backend proxy is required for public deployment.
6. **Medical safety** — scraped text can be incomplete or outdated; must never be
   labeled "verified" without a review process; AI output must be labeled.

## 5. Decisions taken

* Keep `MedEx/` and its reports untouched; build v2 in `pharmapath_app/`.
* Replace the token-gated MedEx live catalogue with the self-hosted BD Medicine
  API as the **optional** sync source; all reading/searching works from SQLite.
* Default API base: `http://127.0.0.1:8000` (desktop) / `http://10.0.2.2:8000`
  (Android emulator), always editable in Settings; never a production claim.
* DeepSeek key entered only in Settings, stored in platform secure storage when
  available, never in source, Git, logs, backups or reports. No key is bundled.
* AI is optional and disposable; every non-AI feature works without it.
* Learning content ships as clearly-labelled **sample** Bangla material that can
  be replaced later.
* No login, subscription, paywall, ads or analytics.

## 6. Build/verification plan

`flutter analyze`, unit tests for DB search/quiz scoring/API parsing, debug APK
build. Linux desktop build needs `libsecret-1-dev` for secure storage and is
documented rather than claimed. Web has no SQLite backend and is not a supported
target in v2.
