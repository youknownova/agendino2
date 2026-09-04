param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$base = "$env:USERPROFILE\OneDrive\Documents"
$vault = 'C:\Users\junio\GitHub\titaria-vault\Notes'
$today = '2026-06-15'

$exts = @('.txt','.md','.markdown')
# Strong junk filters (path + name + tiny)
$junkPathRx = 'security-ninja-premium|Brand-Assets|\\node_modules\\|\\vendor\\'
$junkNameRx = '\.hda( \(\d+\))?\.txt$|transcription_[a-f0-9]{6}|videoplayback|^License (free|premium)|^Loliette|^pc specs|^SFTP|^t\.txt$|^text\.txt$|Perfect Prompts|plugin marketplace|lifecycle posture from|whats different|DMARC record|Michael is working|its a contract|^Subcontractor Management Solution M\.txt|pc specs|Formatted_Event_Table|^\{|^\d*Untitl|citation-\d+|htaccess|debugger-log|system-status|stm-calc|CITATION FINDER|google tag|^Links|^\.et-l|really-simple-ssl|agent-log|jira_import_template|^Login URL|robots\.txt|\.min\.|ExceptionLog|whitelist|10k-most-common|wifi\.md$|snag\.txt|^ddaf|^znn|^jj\.txt|^ff\.txt|^zz|sqlaccount|userlist|wireless code|irs pin|^! Download|null\.txt|^\d+\.\)|^4 groups|^Atlantis\.|^Compass\.|^From2?\.txt|^Fonts|^Data\.txt|^backup\.txt|Edu Footprint|BadgePrintingService|Chase Routing|^Delivered-To|^automations@|cloudflare-info@|@fyrespace\.com\.txt|^ET-R\d|_ORGANIZATION-LOG|_sort-log|FAQ Schema Template|blog-title-examples|ai-generated-checklist|-license\.txt|avada|nanosoft|CSV-configuration|EAI (Desktops|Laptops)|EAT (Desktops|Laptops)|^Goals for|^IBA Draft|^000\d|^From\.txt|^1\.\)|Edu Footprint|Fonts\.txt|RCA Alarm|Webdesign keywords'

# Ordered classification rules: Folder | regex on basename
$rules = @(
  @('Side Business\FyreSpace',              'PATH:FyreSpace'),
  @('Side Business\FyreSpace',              '(lead generation|smartlead|amplify|spintax|hvac|air condition|ice.?bucket|pure.?tek|engagement letter|automation agency|cowork|crm intake|web ?design|seo)'),
  @('Personal\Finance',                     '(financial planning|investment strateg|insurance (planning|consultation)|health insurance|homeowner trust|budget allocation for f|fy26 budget)'),
  @('Personal\Family & Life',               '(hunting|holiday refl|mindset|family|work-life|personal preferences|identity and spiritual|separation of church|new year team|personal (matters|updates)|economy|arc thrower|pregnancy|announcement)'),
  @('Personal\Finance',                     '(insurance info|policy information)'),
  @('People & 1-on-1s\Career, Promotion & Talent','(promotion|job expectation|career|talent|retention|delegation in team|feedback and delegation|transition planning for project management role|distribution groups|interview|termination|employee exit|new hire|hiring|hybrid work|work from home|growth plans|management empowerment|john clifford|steven textor|oksana|onboarding)'),
  @('People & 1-on-1s\Performance & Reviews','(performance (evaluation|review|issues)|employee performance|evaluation of .+performance)'),
  @('IT Leadership & PMO\AI, Automation & Tools','(ai (integration|automation|tool|innovation)|automation strateg|leveraging ai|conversational intelligence|oco board)'),
  @('IT Leadership & PMO\Feasibility Study & Platforms','(feasibility|microsoft and google|google workspace|vendor migration|info-tech|software assessment)'),
  @('IT Leadership & PMO\Portfolio & Governance','(portfolio|okr|pmo (process|governance|expectation|off-site)|tool standardization|executive communication|it leadership|it pmo|agile certification|capacity planning|folder structure|management challenges)'),
  @('SAP Program\HyperCare',                '(atlas|servicenow|hypercare|itsm|transition to operate|operate model|ticket (management|routing)|support ticketing|change ?scout)'),
  @('SAP Program\ANSCO & OpsCenter',        '(ansco|opcenter|opscenter|op center|pop replacement)'),
  @('SAP Program\Cutover & Go-Live',        '(cutover|go.?live|go.?no.?go|dress rehearsal|business freeze|production (release|deployment|management))'),
  @('SAP Program\Data Migration & Conversion','(data (migration|load|conversion|readiness|validation|integration)|reconciliation|mc1|wip tie|tie.?out|sales order load|system copy)'),
  @('SAP Program\Defects, Access & Security','(defect|access|security|role (mapping|assignment|clarity)|authorization|grc|ricefid|permission|single sign|login verification|service account|user account)'),
  @('SAP Program\Testing & UAT',            '(uat|test (case|script|plan|data|cycle|assignment|strategy)|testing|regression|zephyr|alm|scenario|sprint planning|functional spec)'),
  @('SAP Program\Program Status & Governance','(status|raid|risk|coordination|project (management|update|timeline|planning|progress)|stakeholder|governance|knowledge transfer|sap|jira|s4|hcm|operations review|management meeting|team meeting|sales and finance|budget|reporting|billing|sac|datasphere|erp|ewm|vendor|adp|mc2|itc1|itc2|wfs|craftpay|incident|approval|certificate-based|sla and change|velocity app|demo planning|equipment|matrix call|distribution group|dicom|purchase order|engagement|conversation with)'),
  @('SAP Program\Program Status & Governance','(meeting|discussion|conversation|call|review|update|planning|recap|summary|insights|workshop|session|overview|challenges|dynamics|integration|implementation|process|project|team|transition|troubleshoot|management|communication|workload|material|teams|tracker|concerns|navigating|difficult|sustainability)')
)

$files = Get-ChildItem $base -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $exts -contains $_.Extension.ToLower() -and $_.FullName -notmatch $junkPathRx -and $_.Name -notmatch $junkNameRx -and $_.Length -gt 40 }

$map = @()
foreach ($f in $files) {
  $name = $f.BaseName
  $isFyre = $f.FullName -match '\\FyreSpace\\'
  $dest = $null
  foreach ($r in $rules) {
    $pat = $r[1]
    if ($pat -eq 'PATH:FyreSpace') { if ($isFyre) { $dest = $r[0]; break } else { continue } }
    if ($name -imatch $pat) { $dest = $r[0]; break }
  }
  if (-not $dest) { $dest = '_Unsorted' }
  $map += [pscustomobject]@{ File=$f.FullName; Folder=$dest; Name=$f.Name }
}

$map | Group-Object Folder | Sort-Object Name | ForEach-Object { '{0,5}  {1}' -f $_.Count, $_.Name }
Write-Host "TOTAL to import: $($map.Count)"
$map | Sort-Object Folder,Name | ForEach-Object { "$($_.Folder)`t$($_.Name)" } | Set-Content 'C:\Users\junio\GitHub\agendino2\import-manifest.tsv' -Encoding UTF8

if ($Apply) {
  $copied=0; $skipped=0
  foreach ($row in $map) {
    $targetDir = Join-Path $vault $row.Folder
    New-Item -ItemType Directory -Force $targetDir | Out-Null
    $mdName = [IO.Path]::GetFileNameWithoutExtension($row.Name) + '.md'
    $target = Join-Path $targetDir $mdName
    if (Test-Path -LiteralPath $target) { $mdName = [IO.Path]::GetFileNameWithoutExtension($row.Name) + '-doc.md'; $target = Join-Path $targetDir $mdName }
    if (Test-Path -LiteralPath $target) { $skipped++; continue }
    $content = Get-Content -LiteralPath $row.File -Raw -ErrorAction SilentlyContinue
    $rel = $row.File.Substring($base.Length+1)
    $fm = "---`nsource: Documents import`noriginal_path: `"$rel`"`nimported: $today`n---`n`n"
    [IO.File]::WriteAllText($target, $fm + $content, (New-Object System.Text.UTF8Encoding($false)))
    $copied++
  }
  Write-Host "APPLIED: copied $copied, skipped(existing) $skipped"
}
