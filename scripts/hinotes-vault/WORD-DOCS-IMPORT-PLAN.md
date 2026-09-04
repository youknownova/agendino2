# Word Documents → Obsidian Import Plan

> **STATUS: EXECUTED (2026-06-15).** pandoc + Word COM installed/used. `.docx` imported via
> `import-word-docs.ps1` (1,069 in, 12 secrets quarantined, 7 failed); legacy `.doc`/`.rtf`/`.odt`
> via `import-legacy-docs.ps1` (87 in). LibreOffice install failed (MSI 1603) — Word COM was used
> instead. Cleanup of originals via `cleanup-originals.ps1` (run after you verify the vault).
> The notes below are the original plan, kept for reference / re-runs.

Plan to bring the ~1,240 Word documents in `OneDrive\Documents` into the vault, converted to
Markdown and classified into the taxonomy — the same way `.txt`/`.md` notes were handled.

Categorization is **already done** (content-based) by `categorize-word-docs.ps1` →
`_artifacts/word-docs-manifest.tsv`. This plan covers conversion + placement, which is not yet executed.

## Current state (from `word-docs-manifest.tsv`, 1,238 files)

| Bucket | Count | Notes |
|---|---:|---|
| `Side Business\FyreSpace` | 721 | bulk — business docs, SOPs, client pages, marketing |
| `_Unsorted` | 130 | no keyword match — needs review or content re-pass |
| `Personal\Family & Life` | 104 | over-matches "resume"/"family"; review (some are FyreSpace/legal) |
| `SAP Program\*` | ~103 | Testing 52, Status 33, Cutover 7, others |
| `People & 1-on-1s\*` | ~46 | consent/offer letters, interviews |
| `Personal\Finance` | 15 | tax/insurance/estate |
| `IT Leadership & PMO\*` | 5 | |
| `NEEDS-CONVERSION (.doc)` | 86 | legacy binary — pandoc can't read; convert via LibreOffice |
| `NEEDS-CONVERSION (.rtf)` | 10 | |
| `NEEDS-CONVERSION (.odt)` | 1 | |
| `SECRET` (flagged) | 17 | **name-based, mostly false positives** — review (see below) |
| unreadable `.docx` | 5 | corrupt / non-standard zip — handle manually |

## Tooling required
1. **pandoc** — `winget install --id JohnMacFarlane.Pandoc -e` (or `choco install pandoc`).
   Converts `.docx` → GitHub-flavored Markdown.
2. **LibreOffice** — `winget install --id TheDocumentFoundation.LibreOffice -e`.
   Headless-converts legacy `.doc`/`.rtf`/`.odt` → `.docx` so pandoc can then read them:
   `soffice --headless --convert-to docx --outdir <tmp> <file>`.
   (Alternative: Word COM automation if Office is installed.)

## Steps

### 1. Install tooling
Install pandoc (+ LibreOffice for the 97 legacy files). Verify: `pandoc --version`.

### 2. Re-categorize the legacy files
After LibreOffice converts `.doc`/`.rtf`/`.odt` → `.docx` (into a temp dir), re-run
`categorize-word-docs.ps1 -Base <tmp>` so their content is read and classified (they're currently
`NEEDS-CONVERSION` placeholders). Merge into the manifest.

### 3. Convert + place (new script: `import-word-docs.ps1`, to be written)
For each manifest row that is **not** `SECRET`/`_Unsorted`:
- `pandoc "<src.docx>" -f docx -t gfm -o "<vault>\<Folder>\<name>.md" --wrap=none --extract-media=<vault>\_attachments\<name>`
- Prepend frontmatter: `source: Documents import (docx)`, `original_path`, `imported: <date>`.
- Preserve `Side Business\FyreSpace` **subfolder structure** (as the `.txt`/`.md` import did) to avoid
  the 721 files colliding on filename in one folder.
- Skip if a same-named note already exists in the target folder (dedupe vs vault).
- **Copy semantics** — leave originals in OneDrive until reviewed.

### 4. Secret handling (do NOT trust the name-based flag)
The 17 `SECRET` flags are mostly policy/SOP docs ("password_protection_policy", "SOP 037 password
manager", even *"The Secret" by Rhonda Byrne*). Only a few are real:
- Likely real → quarantine to `~/.secrets`: `BACKUP VERIFICATION CODES WCN.docx`,
  `Identity Theft Affidavit.docx`, `E-Taxes Info.docx`.
- The rest are notes/SOPs → import normally.
Authoritative pass: **after conversion**, run a content secret-scan on the produced `.md`
(reuse the `$secretRx` in `categorize-word-docs.ps1`) and review hits before moving anything.

### 5. Review buckets
- `_Unsorted` (130): mostly business/personal docs that missed keywords (e.g. `DNC Lead List`,
  `FARBAR - Signed` real-estate, `Daytona Trip`, how-to guides). Either hand-sort or extend the
  rules in `categorize-word-docs.ps1` and re-run.
- `Personal\Family & Life` (104): verify — `resume` and `family` over-match; some are FyreSpace or legal.
- 5 unreadable docx: open manually; likely corrupt or renamed non-Office files.

### 6. Finalize
- Spot-check a sample of converted notes render correctly in Obsidian (tables, lists, images).
- Once satisfied, optionally delete the OneDrive originals.
- Update `_IMPORTED-FROM-DOCS.md` in the vault with the Word-doc counts.

## Why this is staged, not one-shot
- **~1,240 conversions** is heavy; run in the background and review the manifest first.
- **Conversion fidelity varies** (complex docx, legacy `.doc`) — a dry sample avoids mass-importing junk.
- **Secret safety**: name-based flags are noisy; the reliable scan happens on converted text.
- The bulk (721 FyreSpace) is business collateral, not meeting notes — confirm you actually want it
  all in the vault before converting, or scope to a subset (e.g. SOPs + real notes only).

## One-command starting point (after installing pandoc)
```powershell
# dry sample of 20 conversions to a scratch folder to eyeball fidelity
$rows = Import-Csv _artifacts\word-docs-manifest.tsv -Delimiter "`t" -Header Ext,Secret,Folder,Path |
        Where-Object { $_.Ext -eq '.docx' -and $_.Folder -notin 'SECRET','_Unsorted' } | Select-Object -First 20
$rows | ForEach-Object { pandoc $_.Path -f docx -t gfm --wrap=none -o ("scratch\" + (Split-Path $_.Path -LeafBase) + ".md") }
```
