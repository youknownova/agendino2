param(
  [string]$Base = "$env:USERPROFILE\OneDrive\Documents",
  [string]$Vault = 'C:\Users\junio\GitHub\titaria-vault\Notes',
  [string]$Manifest = 'C:\Users\junio\GitHub\agendino2\scripts\hinotes-vault\_artifacts\word-docs-manifest.tsv',
  [string]$SecretsDir = "$env:USERPROFILE\.secrets",
  [int]$Limit = 0,
  [switch]$Apply
)
$ErrorActionPreference = 'Stop'
$pandoc = (Get-Command pandoc -ErrorAction SilentlyContinue).Source
if (-not $pandoc) { $pandoc = "$env:LOCALAPPDATA\Pandoc\pandoc.exe" }
if (-not (Test-Path $pandoc)) { throw "pandoc not found" }

$secretRx = '(?im)(BEGIN [A-Z ]*PRIVATE KEY|otpauth://|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|AIza[0-9A-Za-z_\-]{30,}|sk-[A-Za-z0-9]{20,}|SG\.[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}|recovery code|backup verification code|backup code|password\s*[:=]\s*\S{4}|client[_ ]?secret\s*[:=]|api[_ ]?key\s*[:=]\s*\S|routing number\s*[:#]?\s*\d{6}|account number\s*[:#]?\s*\d{6}|\bssn\b\s*[:#]?\s*\d{3})'

function Safe([string]$s) { ($s -replace '[\\/:*?"<>|]','-').Trim() }

$rows = Import-Csv $Manifest -Delimiter "`t" -Header Ext,Secret,Folder,Path | Where-Object { $_.Ext -eq '.docx' }
if ($Limit -gt 0) { $rows = $rows | Select-Object -First $Limit }
$total = $rows.Count
Write-Host "docx to process: $total  (Apply=$Apply)"

$imported=0; $quarantined=0; $dupes=0; $failed=0; $i=0
$log = @()
foreach ($r in $rows) {
  $i++
  $src = $r.Path
  if (-not (Test-Path -LiteralPath $src)) { continue }
  $leaf = Safe([IO.Path]::GetFileNameWithoutExtension($src))
  $isFyre = $src -match '\\FyreSpace\\'

  # target folder
  if ($isFyre) {
    $rel = $src.Substring($Base.Length+1)                       # FyreSpace\...\name.docx
    $relDir = Split-Path $rel -Parent
    $targetDir = Join-Path (Join-Path $Vault 'Side Business') $relDir
  } else {
    $folder = $r.Folder
    if ($folder -eq 'SECRET') { $folder = '_Unsorted' }          # name-flag is unreliable; rely on content scan below
    $targetDir = Join-Path $Vault $folder
  }
  $targetMd = Join-Path $targetDir ($leaf + '.md')

  # convert to a temp file first so we can secret-scan content
  $tmp = [IO.Path]::Combine($env:TEMP, "wd_$i.md")
  try {
    & $pandoc $src -f docx -t gfm --wrap=none -o $tmp 2>$null
  } catch { $failed++; $log += "FAIL convert`t$src"; continue }
  if (-not (Test-Path $tmp)) { $failed++; $log += "FAIL convert`t$src"; continue }
  $body = Get-Content -LiteralPath $tmp -Raw -ErrorAction SilentlyContinue

  if ($body -and ($body -imatch $secretRx)) {
    # real secret -> quarantine ORIGINAL, do not import
    if ($Apply) {
      New-Item -ItemType Directory -Force $SecretsDir | Out-Null
      $sLeaf = Split-Path $src -Leaf
      $sTarget = Join-Path $SecretsDir $sLeaf
      $n=1; while (Test-Path -LiteralPath $sTarget) { $sTarget = Join-Path $SecretsDir (($leaf)+"_$n"+([IO.Path]::GetExtension($src))); $n++ }
      Move-Item -LiteralPath $src -Destination $sTarget -Force
      "$(Split-Path $sTarget -Leaf)`t$($src.Substring($Base.Length+1))" | Add-Content (Join-Path $SecretsDir '_ORIGIN-MANIFEST.tsv') -Encoding UTF8
    }
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    $quarantined++; $log += "SECRET`t$src"; continue
  }

  if (Test-Path -LiteralPath $targetMd) { $dupes++; Remove-Item $tmp -Force -ErrorAction SilentlyContinue; continue }

  if ($Apply) {
    New-Item -ItemType Directory -Force $targetDir | Out-Null
    $relPath = $src.Substring($Base.Length+1)
    $fm = "---`nsource: Documents import (docx)`noriginal_path: `"$relPath`"`nimported: 2026-06-15`n---`n`n"
    [IO.File]::WriteAllText($targetMd, $fm + $body, (New-Object System.Text.UTF8Encoding($false)))
  }
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  $imported++
  if ($i % 100 -eq 0) { Write-Host "  ...$i/$total  imported=$imported quarantined=$quarantined dup=$dupes" }
}

Write-Host ""
Write-Host "=== DONE. imported=$imported quarantined=$quarantined dupes=$dupes failed=$failed ==="
$log | Set-Content 'C:\Users\junio\GitHub\agendino2\scripts\hinotes-vault\_artifacts\word-import-log.tsv' -Encoding UTF8
