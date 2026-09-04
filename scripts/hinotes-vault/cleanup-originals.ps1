<#
.SYNOPSIS
  After you VERIFY the vault, clean up the source files in OneDrive\Documents that were imported.

  Source of truth = each vault note's `original_path:` frontmatter (every imported copy has one).
  Secrets were already MOVED out of OneDrive (see ~/.secrets\_ORIGIN-MANIFEST.tsv) and are reported
  separately — there is nothing left to delete for those.

.MODES
  (default)      Dry-run. Writes cleanup-review.tsv and prints counts. Changes nothing.
  -Apply         Moves each imported original into a staging recycle folder (reversible).
  -Apply -Hard   Permanently deletes the imported originals (no staging). Use only after review.

.NOTES
  - Only originals that have a vault copy are touched. Not-yet-imported files (legacy .doc/.rtf/.odt,
    failed conversions, skipped duplicates) are left alone.
  - Staging folder defaults to OneDrive\Documents\_IMPORTED-ORIGINALS_TODELETE — delete it yourself
    once you are 100% satisfied, to reclaim space.
#>
param(
  [string]$Vault   = 'C:\Users\junio\GitHub\titaria-vault\Notes',
  [string]$Base    = "$env:USERPROFILE\OneDrive\Documents",
  [string]$Staging = "$env:USERPROFILE\OneDrive\Documents\_IMPORTED-ORIGINALS_TODELETE",
  [string]$OutFile = 'C:\Users\junio\GitHub\agendino2\scripts\hinotes-vault\_artifacts\cleanup-review.tsv',
  [switch]$Apply,
  [switch]$Hard
)
$ErrorActionPreference = 'Stop'

# 1) Collect original_path from every imported vault note
$notes = Get-ChildItem $Vault -Recurse -Filter *.md -File -ErrorAction SilentlyContinue
$seen = @{}; $rows = @()
foreach ($n in $notes) {
  $head = Get-Content $n.FullName -TotalCount 8 -ErrorAction SilentlyContinue
  $m = $head | Select-String -Pattern '^original_path:\s*"(.+)"' | Select-Object -First 1
  if (-not $m) { continue }
  $op = $m.Matches.Groups[1].Value
  if ($seen.ContainsKey($op)) { continue }
  $seen[$op] = $true
  $orig = Join-Path $Base $op
  $rows += [pscustomobject]@{ Exists = (Test-Path -LiteralPath $orig); Original = $op; Vault = $n.FullName.Substring($Vault.Length+1) }
}

$existing = @($rows | Where-Object { $_.Exists })
$missing  = @($rows | Where-Object { -not $_.Exists })

# 2) Write review file
$rows | Sort-Object Original | ForEach-Object { "$([int]$_.Exists)`t$($_.Original)`t$($_.Vault)" } | Set-Content $OutFile -Encoding UTF8

# 3) Secrets already moved (informational)
$secMan = "$env:USERPROFILE\.secrets\_ORIGIN-MANIFEST.tsv"
$secCount = if (Test-Path $secMan) { (Get-Content $secMan | Where-Object { $_ -match "`t" }).Count } else { 0 }

Write-Host "=== CLEANUP REVIEW ==="
Write-Host "Imported originals with a vault copy : $($rows.Count)"
Write-Host "  still present in OneDrive (cleanable): $($existing.Count)"
Write-Host "  already gone (no action)            : $($missing.Count)"
Write-Host "Secrets already moved to ~/.secrets    : $secCount (originals already removed from OneDrive)"
Write-Host "Review list -> $OutFile"
Write-Host ""

if (-not $Apply) {
  Write-Host "DRY-RUN. Re-run with -Apply to stage originals for deletion (reversible), or -Apply -Hard to delete."
  return
}

$done = 0
foreach ($r in $existing) {
  $src = Join-Path $Base $r.Original
  if (-not (Test-Path -LiteralPath $src)) { continue }
  if ($Hard) {
    Remove-Item -LiteralPath $src -Force
  } else {
    $dst = Join-Path $Staging $r.Original
    New-Item -ItemType Directory -Force (Split-Path $dst -Parent) | Out-Null
    Move-Item -LiteralPath $src -Destination $dst -Force
  }
  $done++
}
if ($Hard) { Write-Host "HARD-DELETED $done imported originals." }
else { Write-Host "STAGED $done originals -> $Staging`nDelete that folder yourself once satisfied." }
