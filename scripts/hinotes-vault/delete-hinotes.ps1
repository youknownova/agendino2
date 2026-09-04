param(
  [string]$Token,
  [int]$Limit = 0,   # 0 = all
  # Only delete notes whose hidock_id is already present in the vault. '' disables the check.
  [string]$VerifyDir = 'C:\Users\junio\GitHub\titaria-vault\Notes',
  [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'

# Build the set of note ids that made it into the vault, so an export that skipped
# or errored on a note can't be followed by an irreversible delete of that note.
$exported = $null
if ($VerifyDir) {
  if (-not (Test-Path $VerifyDir)) { throw "VerifyDir not found: $VerifyDir" }
  $exported = [System.Collections.Generic.HashSet[string]]::new()
  Get-ChildItem -Path $VerifyDir -Filter *.md -File -Recurse | ForEach-Object {
    # hidock_id lives in the frontmatter; only the head of the file needs scanning.
    foreach ($line in (Get-Content -LiteralPath $_.FullName -TotalCount 20)) {
      if ($line -match '^hidock_id:\s*"?([^"\s]+)"?\s*$') { [void]$exported.Add($Matches[1]); break }
    }
  }
  Write-Host "Vault holds $($exported.Count) exported hidock_ids ($VerifyDir)"
}
$h = @{ 'accesstoken' = $Token; 'interface-language' = 'en'; 'accept' = 'application/json' }

# Enumerate all note ids
$all = @()
$pageIndex = 0; $pageSize = 50
while ($true) {
  $url = "https://hinotes.hidock.com/v1/note/recording/list?folderId=-1&pageIndex=$pageIndex&pageSize=$pageSize&sortType=desc&sortField=createtime"
  $resp = Invoke-RestMethod -Uri $url -Headers $h
  $content = $resp.data.content
  if (-not $content) { break }
  $all += $content
  if ($content.Count -lt $pageSize) { break }
  $pageIndex++
  if ($pageIndex -gt 60) { break }
}
Write-Host "Enumerated $($all.Count) notes"

$unexported = @()
if ($exported) {
  $unexported = @($all | Where-Object { -not $exported.Contains([string]$_.id) })
  $all = @($all | Where-Object { $exported.Contains([string]$_.id) })
  Write-Host "Deletable (present in vault): $($all.Count).  Held back (not exported): $($unexported.Count)"
  if ($unexported.Count -gt 0) {
    $unexported | ForEach-Object { "  HOLD $($_.id)`t$($_.title)" } | Write-Host
  }
}
if ($Limit -gt 0) { $all = $all | Select-Object -First $Limit }

if ($WhatIf) {
  Write-Host "WhatIf: would delete $($all.Count) notes. Nothing was deleted."
  return
}

$ok = 0; $fail = @(); $i = 0
foreach ($n in $all) {
  $i++
  try {
    $r = Invoke-RestMethod -Uri 'https://hinotes.hidock.com/v1/note/delete' -Method Post -Headers $h -Form @{ id = $n.id }
    if ($r.error -eq 0) { $ok++; Write-Host "[$i/$($all.Count)] DELETED: $($n.title)" }
    else { $fail += $n; Write-Host "[$i/$($all.Count)] FAIL(err=$($r.error)): $($n.title)" }
  } catch {
    $fail += $n; Write-Host "[$i/$($all.Count)] ERROR: $($n.title) -> $($_.Exception.Message)"
  }
}
Write-Host ""
Write-Host "=== DELETE DONE. Deleted: $ok, Failed: $($fail.Count), Held back: $($unexported.Count) ==="
