# READ-ONLY. Flags already-imported vault notes that should NOT have been imported,
# by matching exclusion rules against each row of cleanup-review.tsv (Exists\tOriginal\tVault).
# Writes _artifacts/review-personal.tsv (Reason\tOriginal\tVault) for human review. Deletes nothing.
param(
  [string]$Review = "$PSScriptRoot\_artifacts\cleanup-review.tsv",
  [string]$Out    = "$PSScriptRoot\_artifacts\review-personal.tsv"
)
$ErrorActionPreference = 'Stop'

# Ordered exclusion rules: Reason | regex (matched against the ORIGINAL source path only,
# case-insensitive). Matching the vault path too caused false positives from taxonomy folder
# names like "Family & Life" / "Finance". First match wins. Unmatched rows are left untouched.
$rules = @(
  @('Resume/CV',          '(?i)(resume|curriculum vitae|\bcv\b)'),
  @('Personal folder',    '(?i)(^_Personal\\|^Personal\\|Personal-Documents|Personal Documents)'),
  @('DY folder',          '(?i)^DY\\'),
  @('Template',           '(?i)\\Templates?\\'),
  @('Consent/Offer ltr',  '(?i)(consent letter|offer letter)'),
  @('Family/Emergency',   '(?i)(family emergency|emergency binder)'),
  @('Financial/Tax',      '(?i)(tax return|w-2|\b401k\b|bank statement|estate plan)'),
  @('Medical/Health',     '(?i)(medical|health record|prescription|diagnosis)')
)

$flagged = @()
foreach ($line in (Get-Content -LiteralPath $Review)) {
  $parts = $line -split "`t", 3
  if ($parts.Count -lt 3) { continue }
  $orig = $parts[1]; $vault = $parts[2]
  foreach ($r in $rules) {
    if ($orig -match $r[1]) { $flagged += [pscustomobject]@{ Reason=$r[0]; Original=$orig; Vault=$vault }; break }
  }
}

$flagged | Sort-Object Reason, Original |
  ForEach-Object { "$($_.Reason)`t$($_.Original)`t$($_.Vault)" } |
  Set-Content -LiteralPath $Out -Encoding UTF8

Write-Host "=== FLAGGED FOR REVIEW (should NOT have been imported) ==="
$flagged | Group-Object Reason | Sort-Object Count -Descending |
  ForEach-Object { '{0,5}  {1}' -f $_.Count, $_.Name }
Write-Host ("-"*40)
Write-Host ("TOTAL flagged: {0} of {1} imported" -f $flagged.Count, ((Get-Content -LiteralPath $Review).Count))
Write-Host "Full list -> $Out"
