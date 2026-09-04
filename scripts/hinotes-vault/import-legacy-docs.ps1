param(
  [string]$Base = "$env:USERPROFILE\OneDrive\Documents",
  [string]$Vault = 'C:\Users\junio\GitHub\titaria-vault\Notes',
  [string]$SecretsDir = "$env:USERPROFILE\.secrets",
  [int]$Limit = 0,
  [switch]$Apply
)
# Converts legacy .doc/.rtf/.odt via Word COM -> .docx, then pandoc -> Markdown, classifies by
# content, content-scans for secrets, and imports into the vault with correct original_path.
$ErrorActionPreference = 'Continue'
$pandoc = (Get-Command pandoc -ErrorAction SilentlyContinue).Source
if (-not $pandoc) { $pandoc = "$env:LOCALAPPDATA\Pandoc\pandoc.exe" }

$secretRx = '(?im)(BEGIN [A-Z ]*PRIVATE KEY|otpauth://|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|AIza[0-9A-Za-z_\-]{30,}|sk-[A-Za-z0-9]{20,}|SG\.[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}|recovery code|backup verification code|backup code|password\s*[:=]\s*(?!create|enter|request|your|the |a )\S{4}|client[_ ]?secret\s*[:=]|api[_ ]?key\s*[:=]\s*\S|routing number\s*[:#]?\s*\d{6}|account number\s*[:#]?\s*\d{6}|\bssn\b\s*[:#]?\s*\d{3})'

$rules = @(
  @('Personal\Finance','(financial planning|investment strateg|insurance (policy|info)|homeowner trust|401k|retirement|estate plan|tax return|w-2|mortgage)'),
  @('Personal\Family & Life','(hunting|holiday|family|work-life|wedding|birthday|pregnancy|spiritual|personal journal|resume)'),
  @('Side Business\FyreSpace','PATH:FyreSpace'),
  @('Side Business\FyreSpace','(fyrespace|lead generation|smartlead|amplify|spintax|hvac|air condition|ice.?bucket|pure.?tek|engagement letter|automation agency|crm intake|web ?design|\bseo\b|wordpress|marketing funnel)'),
  @('People & 1-on-1s\Career, Promotion & Talent','(promotion|job expectation|career|talent management|retention|interview|termination|employee exit|new hire|hiring|consent letter|offer letter|onboarding)'),
  @('People & 1-on-1s\Performance & Reviews','(performance (evaluation|review)|employee performance|annual review|self-assessment)'),
  @('IT Leadership & PMO\AI, Automation & Tools','(ai (integration|automation|tool)|automation strateg|prompt engineering)'),
  @('IT Leadership & PMO\Feasibility Study & Platforms','(feasibility|microsoft and google|google workspace|vendor migration|info-tech|software assessment)'),
  @('IT Leadership & PMO\Portfolio & Governance','(portfolio management|okr|pmo (process|governance)|tool standardization|it leadership|it pmo|capacity planning)'),
  @('SAP Program\HyperCare','(atlas|servicenow|hypercare|itsm|transition to operate|operate model|ticket (management|routing)|support ticketing)'),
  @('SAP Program\ANSCO & OpsCenter','(ansco|opcenter|opscenter|op center|pop replacement)'),
  @('SAP Program\Cutover & Go-Live','(cutover|go.?live|go.?no.?go|dress rehearsal|business freeze|production (release|deployment))'),
  @('SAP Program\Data Migration & Conversion','(data (migration|load|conversion|readiness|validation)|reconciliation|wip tie|tie.?out|sales order load|system copy)'),
  @('SAP Program\Defects, Access & Security','(defect|access request|security role|authorization|grc|ricefid|permission|single sign|provisioning|active directory)'),
  @('SAP Program\Testing & UAT','(uat|test (case|script|plan|cycle|strategy)|testing|regression|zephyr|\balm\b|functional spec)'),
  @('SAP Program\Program Status & Governance','(status|raid|risk|coordination|project (management|plan|update|timeline)|stakeholder|governance|knowledge transfer|\bsap\b|\bjira\b|meeting minutes|agenda|sow|statement of work)')
)
function Classify($name,$body,$isFyre){ $hay="$name`n$body"; foreach($r in $rules){ if($r[1] -eq 'PATH:FyreSpace'){ if($isFyre){return $r[0]} else {continue} }; if($hay -imatch $r[1]){return $r[0]} }; return '_Unsorted' }
function Safe($s){ ($s -replace '[\\/:*?"<>|]','-').Trim() }

$exts = @('.doc','.rtf','.odt')
$files = Get-ChildItem $Base -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $exts -contains $_.Extension.ToLower() -and $_.FullName -notmatch 'security-ninja|\\vendor\\' }
if ($Limit -gt 0) { $files = $files | Select-Object -First $Limit }
Write-Host "Legacy files: $($files.Count) (Apply=$Apply)"

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
$tmpRoot = Join-Path $env:TEMP 'legacy_conv'
New-Item -ItemType Directory -Force $tmpRoot | Out-Null

$imported=0; $quarantined=0; $dupes=0; $failed=0; $i=0; $log=@()
foreach ($f in $files) {
  $i++
  $tmpDocx = Join-Path $tmpRoot ("c$i.docx")
  try {
    $doc = $word.Documents.Open($f.FullName, $false, $true)
    $doc.SaveAs2($tmpDocx, 16)   # 16 = wdFormatDocumentDefault (.docx)
    $doc.Close($false)
  } catch { $failed++; $log += "FAIL-CONVERT`t$($f.FullName)"; continue }

  $body = & $pandoc $tmpDocx -f docx -t gfm --wrap=none 2>$null
  $bodyText = ($body -join "`n")
  Remove-Item $tmpDocx -Force -ErrorAction SilentlyContinue

  $isFyre = $f.FullName -match '\\FyreSpace\\'
  if ($bodyText -and ($bodyText -imatch $secretRx)) {
    if ($Apply) {
      New-Item -ItemType Directory -Force $SecretsDir | Out-Null
      $st = Join-Path $SecretsDir (Split-Path $f.FullName -Leaf)
      $n=1; while(Test-Path -LiteralPath $st){ $st = Join-Path $SecretsDir ((Safe([IO.Path]::GetFileNameWithoutExtension($f.Name)))+"_$n"+$f.Extension); $n++ }
      Move-Item -LiteralPath $f.FullName -Destination $st -Force
      "$(Split-Path $st -Leaf)`t$($f.FullName.Substring($Base.Length+1))" | Add-Content (Join-Path $SecretsDir '_ORIGIN-MANIFEST.tsv') -Encoding UTF8
    }
    $quarantined++; $log += "SECRET`t$($f.FullName)"; continue
  }

  $folder = Classify $f.Name $bodyText $isFyre
  if ($isFyre) {
    $rel = $f.FullName.Substring($Base.Length+1); $relDir = Split-Path $rel -Parent
    $targetDir = Join-Path (Join-Path $Vault 'Side Business') $relDir
  } else { $targetDir = Join-Path $Vault $folder }
  $leaf = Safe([IO.Path]::GetFileNameWithoutExtension($f.Name))
  $targetMd = Join-Path $targetDir ($leaf + '.md')
  if (Test-Path -LiteralPath $targetMd) { $dupes++; continue }

  if ($Apply) {
    New-Item -ItemType Directory -Force $targetDir | Out-Null
    $rel = $f.FullName.Substring($Base.Length+1)
    $fm = "---`nsource: Documents import ($($f.Extension.TrimStart('.')))`noriginal_path: `"$rel`"`nimported: 2026-06-15`n---`n`n"
    [IO.File]::WriteAllText($targetMd, $fm + $bodyText, (New-Object System.Text.UTF8Encoding($false)))
  }
  $imported++
  if ($i % 25 -eq 0) { Write-Host "  ...$i/$($files.Count) imported=$imported quarantined=$quarantined" }
}
$word.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
Write-Host ""
Write-Host "=== DONE. imported=$imported quarantined=$quarantined dupes=$dupes failed=$failed ==="
$log | Set-Content 'C:\Users\junio\GitHub\agendino2\scripts\hinotes-vault\_artifacts\legacy-import-log.tsv' -Encoding UTF8
