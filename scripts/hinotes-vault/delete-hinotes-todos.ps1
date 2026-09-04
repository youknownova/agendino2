param(
  [string]$Token,
  [string]$State = 'open',
  [int]$Limit = 0   # 0 = all
)
$ErrorActionPreference = 'Stop'
$h = @{ 'accesstoken' = $Token; 'interface-language' = 'en'; 'accept' = 'application/json' }

# Enumerate all todos of the given state
$ids = @(); $titles = @{}
$pageIndex = 0; $pageSize = 100
while ($true) {
  $url = "https://hinotes.hidock.com/v1/todo/list?pageIndex=$pageIndex&pageSize=$pageSize&state=$State"
  $resp = Invoke-RestMethod -Uri $url -Headers $h
  $content = $resp.data.content
  if (-not $content) { break }
  foreach ($t in $content) { $ids += $t.id; $titles[$t.id] = $t.description }
  if ($resp.data.last -eq $true -or $content.Count -lt $pageSize) { break }
  $pageIndex++
  if ($pageIndex -gt 200) { break }
}
$ids = $ids | Select-Object -Unique
Write-Host "Enumerated $($ids.Count) '$State' todos"
if ($Limit -gt 0) { $ids = $ids | Select-Object -First $Limit }

$ok = 0; $fail = 0; $i = 0
foreach ($id in $ids) {
  $i++
  try {
    $r = Invoke-RestMethod -Uri 'https://hinotes.hidock.com/v1/todo/delete' -Method Post -Headers $h -Form @{ id = $id }
    if ($r.error -eq 0) { $ok++ } else { $fail++; Write-Host "[$i] FAIL(err=$($r.error)) id=$id" }
  } catch { $fail++; Write-Host "[$i] ERROR id=$id -> $($_.Exception.Message)" }
  if ($i % 250 -eq 0) { Write-Host "  ...$i/$($ids.Count) deleted" }
}
Write-Host ""
Write-Host "=== TODO DELETE DONE. Deleted: $ok, Failed: $fail ==="
