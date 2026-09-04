$ErrorActionPreference = 'Stop'
$base = "$env:USERPROFILE\OneDrive\Documents"
$outDir = 'C:\Users\junio\GitHub\agendino2'
$vaultNotes = 'C:\Users\junio\GitHub\titaria-vault\Notes'

# Existing vault note basenames (to flag duplicates)
$existing = @{}
Get-ChildItem $vaultNotes -Recurse -Filter *.md -File | ForEach-Object { $existing[$_.BaseName.ToLower()] = $true }

# --- Secret detection across ALL files (name-based), filtering false positives ---
$fpPathRx = 'security-ninja-premium|Brand-Assets|imgbin|kisspng|node_modules|\\vendor\\|\.php$|\.js$'
$nameSecretRx = 'recovery.?key|recovery.?code|backup.?code|2fa|mfa|seed.?phrase|private.?key|credential|\.env$|bitlocker|otpauth|social-media-credential|wordpress-password|wp-password'
$allFiles = Get-ChildItem $base -Recurse -File -ErrorAction SilentlyContinue
$secretByName = $allFiles | Where-Object { $_.Name -imatch $nameSecretRx -and $_.FullName -notmatch $fpPathRx }

# --- Content secret detection (strong patterns) on .txt/.md only ---
$contentRx = '(BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY|otpauth://|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|xox[baprs]-[A-Za-z0-9-]+|AIza[0-9A-Za-z_\-]{30,}|sk-[A-Za-z0-9]{20,}|recovery code|backup code|seed phrase|mnemonic phrase|client[_ ]?secret|auth[_ ]?token|twilio)'
$textFiles = $allFiles | Where-Object { @('.txt','.md','.markdown') -contains $_.Extension.ToLower() }
$secretByContent = foreach ($f in $textFiles) {
  try {
    $c = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop
    if ($c -imatch $contentRx) { $f }
  } catch {}
}

$secrets = @($secretByName) + @($secretByContent) | Sort-Object FullName -Unique

# --- Note candidates: .txt/.md NOT secrets, NOT obvious non-notes ---
$nonNoteRx = 'htaccess|jira_import_template|login url|^\{|requirements\.txt|package(-lock)?\.json|\.min\.|robots\.txt|sitemap|\.sql|changelog|license\.txt|export.*\.txt$'
$secretPaths = @{}; $secrets | ForEach-Object { $secretPaths[$_.FullName] = $true }
$noteCands = foreach ($f in $textFiles) {
  if ($secretPaths.ContainsKey($f.FullName)) { continue }
  if ($f.Name -imatch $nonNoteRx) { continue }
  $dup = if ($existing.ContainsKey($f.BaseName.ToLower())) { 'DUP' } else { '' }
  $rel = $f.DirectoryName.Substring([math]::Min($base.Length+1, $f.DirectoryName.Length)).TrimStart('\')
  if ([string]::IsNullOrEmpty($rel)) { $rel = '(root)' }
  [pscustomobject]@{ Dup=$dup; Ext=$f.Extension.ToLower(); Folder=$rel; Name=$f.Name; Full=$f.FullName }
}

# --- Reports ---
Write-Host "===== SECRETS (name+content, FPs filtered): $($secrets.Count) ====="
$secrets | ForEach-Object { $_.FullName.Substring($base.Length+1) }
$secrets | ForEach-Object { $_.FullName } | Set-Content "$outDir\secrets-list.txt" -Encoding UTF8

Write-Host ""
Write-Host "===== NOTE CANDIDATES (.txt/.md): $($noteCands.Count)  (DUP of vault: $(@($noteCands|? {$_.Dup -eq 'DUP'}).Count)) ====="
Write-Host "By extension:"; $noteCands | Group-Object Ext | ForEach-Object { '  {0,4}  {1}' -f $_.Count, $_.Name }
Write-Host "By top folder:"; $noteCands | Group-Object { ($_.Folder -split '\\')[0] } | Sort-Object Count -Descending | ForEach-Object { '  {0,4}  {1}' -f $_.Count, $_.Name }
$noteCands | Sort-Object Folder,Name | ForEach-Object { "$($_.Dup)`t$($_.Full)" } | Set-Content "$outDir\note-candidates.txt" -Encoding UTF8
Write-Host ""
Write-Host "Sample 30 note candidate names:"
$noteCands | Where-Object { $_.Dup -ne 'DUP' } | Select-Object -First 30 | ForEach-Object { "  [$($_.Ext)] $($_.Name)" }
