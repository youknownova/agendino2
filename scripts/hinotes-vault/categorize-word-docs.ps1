param(
  [string]$Base = "$env:USERPROFILE\OneDrive\Documents",
  [string]$OutFile = 'C:\Users\junio\GitHub\agendino2\word-docs-manifest.tsv',
  [int]$Limit = 0,            # 0 = all
  [int]$SnippetChars = 4000   # how much body text to read for classification
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

# --- Native .docx text extraction (no pandoc needed) ---
function Get-DocxText([string]$path, [int]$max) {
  try {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($path)
    try {
      $entry = $zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' } | Select-Object -First 1
      if (-not $entry) { return '' }
      $sr = New-Object System.IO.StreamReader($entry.Open())
      $xml = $sr.ReadToEnd(); $sr.Close()
    } finally { $zip.Dispose() }
    $xml = $xml -replace '</w:p>', "`n" -replace '<w:tab/>', ' ' -replace '<w:br/>', "`n"
    $txt = [regex]::Replace($xml, '<[^>]+>', '')
    $txt = [System.Net.WebUtility]::HtmlDecode($txt)
    if ($max -gt 0 -and $txt.Length -gt $max) { $txt = $txt.Substring(0, $max) }
    return $txt
  } catch { return $null }
}

# --- Taxonomy rules (content + name).  First match wins. ---
$rules = @(
  @('Personal\Finance',                       '(financial planning|investment strateg|insurance (policy|info)|homeowner trust|401k|retirement|estate plan|tax return|w-2|w2 |mortgage)'),
  @('Personal\Family & Life',                 '(hunting|holiday|family|work-life|wedding|birthday|pregnancy|spiritual|church and state|personal journal|resume)'),
  @('Side Business\FyreSpace',                'PATH:FyreSpace'),
  @('Side Business\FyreSpace',                '(fyrespace|lead generation|smartlead|amplify|spintax|hvac|air condition|ice.?bucket|pure.?tek|engagement letter|automation agency|crm intake|web ?design|\bseo\b|wordpress|client onboarding|marketing funnel)'),
  @('People & 1-on-1s\Career, Promotion & Talent','(promotion|job expectation|career|talent management|retention|interview|termination|employee exit|new hire|hiring|consent letter|offer letter|onboarding)'),
  @('People & 1-on-1s\Performance & Reviews', '(performance (evaluation|review)|employee performance|annual review|self-assessment)'),
  @('IT Leadership & PMO\AI, Automation & Tools','(ai (integration|automation|tool)|automation strateg|prompt engineering|agent skill)'),
  @('IT Leadership & PMO\Feasibility Study & Platforms','(feasibility|microsoft and google|google workspace|vendor migration|info-tech|software assessment)'),
  @('IT Leadership & PMO\Portfolio & Governance','(portfolio management|okr|pmo (process|governance)|tool standardization|it leadership|it pmo|capacity planning)'),
  @('SAP Program\HyperCare',                  '(atlas|servicenow|hypercare|itsm|transition to operate|operate model|ticket (management|routing)|support ticketing)'),
  @('SAP Program\ANSCO & OpsCenter',          '(ansco|opcenter|opscenter|op center|pop replacement)'),
  @('SAP Program\Cutover & Go-Live',          '(cutover|go.?live|go.?no.?go|dress rehearsal|business freeze|production (release|deployment))'),
  @('SAP Program\Data Migration & Conversion','(data (migration|load|conversion|readiness|validation)|reconciliation|wip tie|tie.?out|sales order load|system copy)'),
  @('SAP Program\Defects, Access & Security', '(defect|access request|security role|authorization|grc|ricefid|permission|single sign|provisioning)'),
  @('SAP Program\Testing & UAT',              '(uat|test (case|script|plan|cycle|strategy)|testing|regression|zephyr|\balm\b|functional spec|test execution)'),
  @('SAP Program\Program Status & Governance','(status|raid|risk|coordination|project (management|plan|update|timeline)|stakeholder|governance|knowledge transfer|\bsap\b|\bjira\b|\bs4\b|\bhcm\b|meeting minutes|agenda|sow|statement of work)')
)
# Strong secret signals in content
$secretRx = '(?im)(BEGIN [A-Z ]*PRIVATE KEY|otpauth://|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|AIza[0-9A-Za-z_\-]{30,}|sk-[A-Za-z0-9]{20,}|SG\.[A-Za-z0-9_\-]{20,}|recovery code|backup code|password\s*[:=]\s*\S|client[_ ]?secret\s*[:=]|api[_ ]?key\s*[:=]|routing number\s*[:#]?\s*\d|account number\s*[:#]?\s*\d|ssn\s*[:#]?\s*\d)'
$secretNameRx = 'password|credential|recovery|backup.?code|2fa|secret|social-media-credential'

function Classify([string]$name, [string]$body, [bool]$isFyre) {
  $hay = "$name`n$body"
  foreach ($r in $rules) {
    if ($r[1] -eq 'PATH:FyreSpace') { if ($isFyre) { return $r[0] } else { continue } }
    if ($hay -imatch $r[1]) { return $r[0] }
  }
  return '_Unsorted'
}

$wordExts = @('.docx','.doc','.rtf','.odt')
$files = Get-ChildItem $Base -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $wordExts -contains $_.Extension.ToLower() -and $_.FullName -notmatch 'security-ninja-premium|\\vendor\\|\\node\w*\\' }
if ($Limit -gt 0) { $files = $files | Select-Object -First $Limit }

$rows = @(); $i = 0; $unreadable = 0
foreach ($f in $files) {
  $i++
  $ext = $f.Extension.ToLower()
  $isFyre = $f.FullName -match '\\FyreSpace\\'
  $body = ''
  if ($ext -eq '.docx') { $body = Get-DocxText $f.FullName $SnippetChars }
  if ($null -eq $body) { $unreadable++; $body = '' }
  $readable = ($ext -eq '.docx')   # native read only for docx

  $secret = ($f.Name -imatch $secretNameRx) -or ($readable -and $body -and ($body -imatch $secretRx))
  if (-not $readable) {
    $folder = 'NEEDS-CONVERSION (.'+$ext.TrimStart('.')+')'
  } elseif ($secret) {
    $folder = 'SECRET'
  } else {
    $folder = Classify $f.Name $body $isFyre
  }
  $rows += [pscustomobject]@{ Ext=$ext; Secret=([int]$secret); Folder=$folder; Path=$f.FullName }
  if ($i % 200 -eq 0) { Write-Host "  ...processed $i/$($files.Count)" }
}

# Report
Write-Host ""
Write-Host "=== Distribution ==="
$rows | Group-Object Folder | Sort-Object Name | ForEach-Object { '{0,5}  {1}' -f $_.Count, $_.Name }
Write-Host "TOTAL: $($rows.Count)  | secret-flagged: $(@($rows|? {$_.Secret -eq 1}).Count)  | unreadable docx: $unreadable"
$rows | Sort-Object Folder,Path | ForEach-Object { "$($_.Ext)`t$($_.Secret)`t$($_.Folder)`t$($_.Path)" } | Set-Content $OutFile -Encoding UTF8
Write-Host "Manifest -> $OutFile"
