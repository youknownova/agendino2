# Removes flagged vault .md copies from Obsidian by MOVING them to a recycle folder OUTSIDE the
# vault (reversible). Keeps anything whose ORIGINAL path is under the -Keep prefix. Deletes nothing
# in OneDrive. Default is dry-run; pass -Apply to actually move.
param(
  [string]$Review = "$PSScriptRoot\_artifacts\review-personal.tsv",
  [string]$Vault  = 'C:\Users\junio\GitHub\titaria-vault\Notes',
  [string]$Recycle= 'C:\Users\junio\GitHub\titaria-vault\_REMOVED-personal-imports',
  [string]$Keep   = '_Personal\_INBOX\Transcriptions-Triage\Transcriptions\',
  [switch]$Apply
)
$ErrorActionPreference = 'Stop'

$moved=0; $kept=0; $missing=0
foreach ($line in (Get-Content -LiteralPath $Review)) {
  $p = $line -split "`t", 3
  if ($p.Count -lt 3) { continue }
  $orig = $p[1]; $vaultRel = $p[2]
  if ($orig.StartsWith($Keep, [StringComparison]::OrdinalIgnoreCase)) { $kept++; continue }

  $src = Join-Path $Vault $vaultRel
  if (-not (Test-Path -LiteralPath $src)) { $missing++; continue }
  $dst = Join-Path $Recycle $vaultRel
  if ($Apply) {
    New-Item -ItemType Directory -Force (Split-Path $dst -Parent) | Out-Null
    if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $src -Force }  # already recycled
    else { Move-Item -LiteralPath $src -Destination $dst -Force }
  }
  $moved++
}
Write-Host "=== REMOVE FLAGGED FROM VAULT (Apply=$Apply) ==="
Write-Host "  kept (under '$Keep'): $kept"
Write-Host "  removed -> recycle  : $moved"
Write-Host "  already gone        : $missing"
if ($Apply) { Write-Host "Recycled to: $Recycle  (delete it yourself once satisfied)" }
else { Write-Host "DRY-RUN. Re-run with -Apply to move." }
