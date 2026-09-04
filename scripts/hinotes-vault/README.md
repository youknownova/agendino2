# HiNotes → Obsidian Vault Toolkit

Reusable PowerShell (7+) scripts for exporting HiNotes, bulk-managing the account, and importing
loose notes from `OneDrive\Documents` into the Obsidian vault (`titaria-vault\Notes`), classifying
everything into one taxonomy and quarantining secrets.

> All scripts are idempotent-ish and safe to dry-run. Destructive ones default to no-op or require
> a `-Token`. Read each section before running.

## Vault taxonomy (target folders)
```
titaria-vault/Notes/
  SAP Program/            Testing & UAT · Cutover & Go-Live · Data Migration & Conversion
                          Defects, Access & Security · ANSCO & OpsCenter · HyperCare
                          Program Status & Governance
  IT Leadership & PMO/    Portfolio & Governance · AI, Automation & Tools · Feasibility Study & Platforms
  People & 1-on-1s/       Career, Promotion & Talent · Performance & Reviews
  Personal/               Finance · Family & Life
  Side Business/          FyreSpace/ (source structure preserved)
  _Unsorted/              ambiguous items to triage
```

## Prerequisites
- PowerShell 7+ (`pwsh`).
- A fresh HiNotes **access token** (for the HiNotes scripts). Get it from the logged-in browser:
  DevTools → Console → `document.cookie.match(/accesstoken=([^;]+)/)[1]` → copy the value.
  Tokens expire; grab a new one per session.
- For Word-doc conversion only: **pandoc** (`.docx`→`.md`) and **LibreOffice** (legacy `.doc`/`.rtf`/`.odt`).
  See `WORD-DOCS-IMPORT-PLAN.md`. Not needed for the HiNotes/txt/md flows.

---

## Scripts

### HiNotes account

| Script | Purpose |
|---|---|
| `export-hinotes.ps1` | Export every HiNotes note → Markdown (summary + timestamped transcript) into the vault. |
| `delete-hinotes.ps1` | Permanently delete every note from the HiNotes account. ⚠️ irreversible. |
| `delete-hinotes-todos.ps1` | Permanently delete to-do items (default `open`). ⚠️ irreversible. |

```powershell
pwsh export-hinotes.ps1       -Token '<TOKEN>' [-OutDir <vault\Notes>] [-Limit N] [-Skip N]
pwsh delete-hinotes.ps1       -Token '<TOKEN>' [-Limit N] [-VerifyDir <vault\Notes>] [-WhatIf]
pwsh delete-hinotes-todos.ps1 -Token '<TOKEN>' [-State open|done] [-Limit N]
```
Always test with `-Limit 1` first. `export` writes `_skipped.log` for notes with no content.

`delete-hinotes.ps1` only deletes notes whose `hidock_id` already appears in a vault note's
frontmatter (`-VerifyDir`, defaults to the vault). Anything the export skipped or errored on is
held back and listed, so an incomplete export can't be followed by an irreversible delete. Run it
with `-WhatIf` first; pass `-VerifyDir ''` to disable the check (not recommended).

### Document import (Downloads / Documents → vault)

| Script | Purpose |
|---|---|
| `scan-docs.ps1` | Scan `OneDrive\Documents` for `.txt`/`.md`; find secrets (name+content) and note candidates; flag vault duplicates. Writes `secrets-list.txt`, `note-candidates.txt`. No changes made. |
| `import-docs.ps1` | Classify `.txt`/`.md` notes into the taxonomy and **copy** them into the vault as `.md` (adds `source`/`original_path` frontmatter). `-Apply` to write; default is dry-run with `import-manifest.tsv`. |
| `classify-notes.ps1` | Re-classify the already-exported HiNotes `.md` notes into folders by keyword rules + manual overrides. `-Apply` to move; writes `notes-manifest.tsv`. Work categories (SAP Program, IT Leadership & PMO, People & 1-on-1s) nest under `-WorkRoot` (default `Dycom`); Personal / Side Business / `_Unsorted` stay at the vault root. Keep `-WorkRoot` consistent between runs or the taxonomy splits across two roots. |
| `categorize-word-docs.ps1` | **Read actual `.docx` content natively** (no pandoc) and categorize each Word doc into the taxonomy; flag likely secrets; mark legacy `.doc`/`.rtf`/`.odt` as needing conversion. Writes `word-docs-manifest.tsv`. Read-only. |
| `import-word-docs.ps1` | Convert `.docx` → Markdown via **pandoc** and place into the vault taxonomy. Content-scans each doc for real secrets (auto-quarantines to `~/.secrets`), adds frontmatter, preserves FyreSpace structure, dedupes. `-Apply` to write; `-Limit N` to test. Needs pandoc. See `WORD-DOCS-IMPORT-PLAN.md`. |
| `cleanup-originals.ps1` | After you verify the vault, clean up the OneDrive source files that were imported (uses each note's `original_path` frontmatter). Dry-run by default → `cleanup-review.tsv`; `-Apply` stages originals into a recycle folder (reversible); `-Apply -Hard` permanently deletes. |

```powershell
pwsh scan-docs.ps1
pwsh import-docs.ps1                 # dry-run -> import-manifest.tsv
pwsh import-docs.ps1 -Apply          # copy into vault
pwsh categorize-word-docs.ps1        # -> word-docs-manifest.tsv  (read-only)
pwsh import-word-docs.ps1 -Limit 25 -Apply   # test docx import
pwsh import-word-docs.ps1 -Apply             # full docx import
pwsh cleanup-originals.ps1                    # dry-run review of what can be deleted
pwsh cleanup-originals.ps1 -Apply             # stage imported originals for deletion (reversible)
pwsh cleanup-originals.ps1 -Apply -Hard       # permanently delete imported originals
```

> **Secrets** found by `scan-docs.ps1` were moved to `C:\Users\junio\.secrets\` with a reversible
> `_ORIGIN-MANIFEST.tsv`. Detection is name+content based and reviewed by hand before moving.

---

## Typical end-to-end workflow
1. `export-hinotes.ps1 -Token …`  → notes into the vault.
2. `classify-notes.ps1 -Apply`    → organize them into folders.
3. `scan-docs.ps1`                → find Documents secrets + note candidates (review).
4. Quarantine confirmed secrets to `~/.secrets` (manual, reviewed).
5. `import-docs.ps1 -Apply`       → bring `.txt`/`.md` notes into the taxonomy.
6. `categorize-word-docs.ps1`     → plan the Word-doc import (see `WORD-DOCS-IMPORT-PLAN.md`).
7. (optional) delete scripts once the account/Documents are cleaned up.

## Artifacts
`_artifacts/` holds run logs and manifests from the last run (`*-run.log`, `*-manifest.tsv`,
`secrets-list.txt`, `note-candidates.txt`). Reference/audit only — safe to delete.

---

## HiNotes API reference (for maintenance)
Header `accesstoken: <token>` (+ `interface-language: en`) on every request. Success = JSON `error: 0`.

| Purpose | Method | Endpoint | Body (multipart) |
|---|---|---|---|
| List notes | GET | `/v1/note/recording/list?folderId=-1&pageIndex=N&pageSize=50&sortType=desc&sortField=createtime` | — |
| Note summary (markdown) | POST | `/v2/note/info` | `id` |
| Transcript | POST | `/v2/note/transcription/list` | `noteId` |
| Delete note | POST | `/v1/note/delete` | `id` |
| List todos | GET | `/v1/todo/list?pageIndex=N&pageSize=100&state=open` | — |
| Delete todo | POST | `/v1/todo/delete` | `id` |

`folderId=-1` = all notes. Todo list is Spring-paginated (`content`, `totalElements`, `last`).
