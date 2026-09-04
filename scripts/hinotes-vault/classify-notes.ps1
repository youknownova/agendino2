param(
  [string]$NotesDir = 'C:\Users\junio\GitHub\titaria-vault\Notes',
  [string]$WorkRoot = 'Dycom',   # work categories nest under this folder; '' = vault root
  [switch]$Apply
)
$ErrorActionPreference = 'Stop'

# Ordered rules: first match wins. Folder | regex (case-insensitive against the filename)
$rules = @(
  @('Personal\Finance',                    '(Financial Planning|Investment Strateg|Homeowner Trust)'),
  @('Personal\Family & Life',              '(Balancing Workload and Family|Personal Preferences and Activities|Identity and Spiritual|Separation of Church)'),
  @('Side Business',                        '(Strategic Acquisition|Business Acquisition|Partnership Development|Business Growth and Strategic|Partnership.*Business Growth)'),
  @('People & 1-on-1s\Performance & Reviews','(Performance Evaluation|Employee Performance|Evaluation of .+Performance|Performance and (Recognition|Contributions)|Team Performance and (HR|Contract))'),
  @('People & 1-on-1s\Career, Promotion & Talent','(Promotion|Career Transition|Career Development|Talent Management|Talent and Retention|Retention Challenges|Merit Cycle|Headcount|Employee Termination|Success Profiles|Leadership Transition and Organizational|Office Seating|Employee Reassignment|Employee Well-being|Employee Benefits)'),
  @('IT Leadership & PMO\Feasibility Study & Platforms','(Feasibility Stud|Microsoft and Google|Google Workspace Renewal|Microsoft Feasibility|Vendor Migration|Info-Tech|Productivity Suite Feasibility)'),
  @('IT Leadership & PMO\Portfolio & Governance','(Portfolio Management|OKR|PMO Process Improvement|PMO Governance|PMO Expectations|Tool Adoption and Data Quality|Project Governance and OKR|Leadership Alignment and Executive|Executive Communication Strategy|Info-Tech Overview|RTAS Project Coordination and Leadership)'),
  @('IT Leadership & PMO\AI, Automation & Tools','(AI Integration|AI and|AI Innovations|Automation Strategies and Onboarding|Project Management Automation|Leveraging AI|AI Tool Integration|Device Management, and PMO)'),
  @('SAP Program\HyperCare',                '(Atlas|ServiceNow|Hypercare|HyperCare|ITSM|Transition to Operate|Operate Model|Ticket Management|Ticket Routing|Support Ticketing|OpsCenter Governance|Introduction to Ticket)'),
  @('SAP Program\ANSCO & OpsCenter',        '(ANSCO|Ansco|OpCenter|OpsCenter|Op Center|POP Replacement)'),
  @('SAP Program\Cutover & Go-Live',        '(Cutover|Go-Live|Go Live|Go-No-Go|Dress Rehearsal|Business Freeze|Project Freeze|Production Release|Production Deployment|Production Management|Phase 2A Go|2A Go-Live|Release 3|ARTAS and PRINCE)'),
  @('SAP Program\Data Migration & Conversion','(Data Migration|Data Load|Data Conversion|Reconciliation|MC1|WIP Tie|Tie-Out|Tie Out|Data Readiness|Data Validation|Sales Order Load|Data Extraction|System Copy|Data Delivery|Data Loading|Data Integration and Cleansing)'),
  @('SAP Program\Defects, Access & Security','(Defect|Access|Security|Role Mapping|Role Assignment|Role Clarity|Roles and Access|Authorization|GRC|RICEFID|Permission|Single Sign|Login Verification|SEC User|Incident Response|Access Control|CRM Role)'),
  @('SAP Program\Testing & UAT',            '(UAT|Test Case|Test Script|Test Plan|Test Data|Test Cycle|Test Assignment|Test Strategy|Test Management|Test Status|Test Update|Test Resource|Testing|Regression|Zephyr|ALM|Scenario|Script|QA Process|Load and Performance|Inventory Testing|Sales Testing|Billing Testing)'),
  @('SAP Program\Program Status & Governance','(Status|RAID|Risk|Program Status|Phase Gate|Phase 2|Phase Two|Phase 3|Coordination|Project Management|Project Updates|Project Update|Project Timeline|Project Planning|Project Progress|Project Status|Project Coordination|Project Document|Project Staffing|Project Capacity|Project Scope|Resource|Onboarding|Team Dynamics|Team Structure|Team Integration|Team Coordination|Team Communication|Milestone|Stakeholder|Governance|Knowledge Transfer|Workflow|Process Improvement|Capacity|Communication|Deliverables|Forecasting|Treasury|Payroll|Billing|Sales|Revenue|Procurement|Property Tax|Contract|System|Integration|Software and Tools|Workload|Strategic Alignment|Next Steps|Phase Gate)')
)

# Manual overrides (hybrid deep-read corrections), keyed by filename
$overrides = @{
  '2025-10-13 Superuser and Change Agent Network Kickoff Preparation.md' = 'SAP Program\Program Status & Governance'
  '2025-10-15 Issue Resolution and Functional Specification Review.md'   = 'SAP Program\Program Status & Governance'
  '2025-10-16 Change Management Strategies and Roles Overview.md'        = 'SAP Program\Program Status & Governance'
  '2025-10-30 Budget and Licensing Challenges with SAP Implementation Issues.md' = 'SAP Program\Program Status & Governance'
  '2025-11-03 Team Performance and Contract Data Challenges.md'          = 'SAP Program\Program Status & Governance'
  '2025-11-04 Data Management and SLA Adjustments Meeting.md'            = 'SAP Program\Program Status & Governance'
  '2025-12-02 Project Task Management and Due Date Adjustments.md'       = 'SAP Program\Program Status & Governance'
  '2025-12-03 Test Documentation and Progress Updates.md'               = 'SAP Program\Testing & UAT'
  '2025-12-16 Discussion on Requirements and RISF Linkage Challenges.md'= 'SAP Program\Program Status & Governance'
  '2025-12-16 Ongoing Issue Resolution and Team Assignments.md'         = 'SAP Program\Program Status & Governance'
  '2025-12-18 Data Management Training on Filtering and Spreadsheet Techniques.md' = 'SAP Program\Program Status & Governance'
  '2026-01-08 Test Progress and Planning for Controllers.md'            = 'SAP Program\Testing & UAT'
  '2026-01-14 Team Progress and SAC Reporting Training.md'              = 'SAP Program\Program Status & Governance'
  '2026-01-26 Project Support and Team Morale Challenges.md'            = 'SAP Program\Program Status & Governance'
  '2026-01-26 Task Dailies Loading and PGI Process Discussion.md'       = 'SAP Program\Data Migration & Conversion'
  '2026-02-17 SAP Implementation and Transition Planning.md'            = 'SAP Program\Program Status & Governance'
  '2026-03-03 License Management and Email Update Process Discussion.md' = 'SAP Program\Program Status & Governance'
  '2026-03-04 Team Accountability and Burnout Challenges.md'            = 'SAP Program\Program Status & Governance'
  '2026-03-10 Troubleshooting Excel and SAP Analytics Cloud Add-in Issues.md' = 'SAP Program\Defects, Access & Security'
  '2026-04-10 Meeting Efficiency and Calendar Management.md'            = 'SAP Program\Program Status & Governance'
  '2026-04-10 Payable Process and Discount Route Impact Discussion.md'  = 'SAP Program\Program Status & Governance'
  '2026-04-10 Project Ownership Transition and Fleetio Planning.md'     = 'IT Leadership & PMO\Portfolio & Governance'
  '2026-04-10 Team Changes and Work Redistribution.md'                  = 'People & 1-on-1s\Career, Promotion & Talent'
  '2026-04-17 Malbec Project & PMO Process Discussion.md'               = 'IT Leadership & PMO\Portfolio & Governance'
  '2026-04-22 Changes in AP and Ops Portal Processes.md'               = 'SAP Program\Program Status & Governance'
  '2026-04-22 SAP Recovery and Enhancement Priorities Meeting.md'       = 'SAP Program\Program Status & Governance'
  '2026-04-29 Fleetio Planning Meeting.md'                              = 'IT Leadership & PMO\Portfolio & Governance'
  '2026-05-07 Platform Development and Automation Strategies.md'        = 'IT Leadership & PMO\AI, Automation & Tools'
}

$files = Get-ChildItem -Path $NotesDir -Filter *.md -File | Where-Object { $_.Name -notlike '_*' }
$map = @()
foreach ($f in $files) {
  $name = $f.BaseName
  $dest = '_Unsorted'
  foreach ($r in $rules) {
    if ($name -imatch $r[1]) { $dest = $r[0]; break }
  }
  if ($overrides.ContainsKey($f.Name)) { $dest = $overrides[$f.Name] }
  # Work categories nest under $WorkRoot; Personal / Side Business / _Unsorted stay at the vault root.
  # Without this the vault ends up with two roots for the same taxonomy (top-level AND Dycom\).
  if ($WorkRoot -and $dest -match '^(SAP Program|IT Leadership & PMO|People & 1-on-1s)($|\\)') {
    $dest = Join-Path $WorkRoot $dest
  }
  $map += [pscustomobject]@{ File = $f.Name; Folder = $dest }
}

# counts
$map | Group-Object Folder | Sort-Object Name | ForEach-Object { '{0,5}  {1}' -f $_.Count, $_.Name }
Write-Host ("TOTAL: {0}" -f $map.Count)

# write manifest
$map | Sort-Object Folder, File | ForEach-Object { "$($_.Folder)`t$($_.File)" } | Set-Content 'C:\Users\junio\GitHub\agendino2\notes-manifest.tsv' -Encoding UTF8

if ($Apply) {
  foreach ($row in $map) {
    $target = Join-Path $NotesDir $row.Folder
    New-Item -ItemType Directory -Force $target | Out-Null
    Move-Item -LiteralPath (Join-Path $NotesDir $row.File) -Destination $target -Force
  }
  Write-Host "APPLIED: moved $($map.Count) files"
}
