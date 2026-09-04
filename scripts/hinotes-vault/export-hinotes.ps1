param(
  [string]$Token,
  [string]$OutDir = 'C:\Users\junio\GitHub\titaria-vault\Notes',
  [int]$Limit = 0,        # 0 = all
  [int]$Skip = 0
)

$ErrorActionPreference = 'Stop'
$h = @{ 'accesstoken' = $Token; 'interface-language' = 'en'; 'accept' = 'application/json' }
New-Item -ItemType Directory -Force $OutDir | Out-Null

function Sanitize([string]$name) {
  $n = $name -replace '[\\/:*?"<>|]', '-'
  $n = $n -replace '\s+', ' '
  $n = $n.Trim().TrimEnd('.')
  if ($n.Length -gt 180) { $n = $n.Substring(0,180).Trim() }
  return $n
}

function MsToTs([long]$ms) {
  $s = [int][math]::Floor($ms/1000); $h2=[int][math]::Floor($s/3600); $m=[int][math]::Floor(($s%3600)/60); $sec=[int]($s%60)
  if ($h2 -gt 0) { return ('{0}:{1:00}:{2:00}' -f $h2,$m,$sec) } else { return ('{0}:{1:00}' -f $m,$sec) }
}

# 1) Enumerate all notes
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

if ($Skip -gt 0) { $all = $all | Select-Object -Skip $Skip }
if ($Limit -gt 0) { $all = $all | Select-Object -First $Limit }

$written = 0; $skipped = @(); $i = 0
foreach ($note in $all) {
  $i++
  $id = $note.id; $title = $note.title
  try {
    $info = Invoke-RestMethod -Uri 'https://hinotes.hidock.com/v2/note/info' -Method Post -Headers $h -Form @{ id = $id }
    $d = $info.data
    $md = if ($d.markdown) { $d.markdown -replace "`r`n", "`n" } else { '' }

    $tr = Invoke-RestMethod -Uri 'https://hinotes.hidock.com/v2/note/transcription/list' -Method Post -Headers $h -Form @{ noteId = $id }
    $sentences = $tr.data

    if (-not $md -and (-not $sentences -or $sentences.Count -eq 0)) {
      $skipped += [pscustomobject]@{ id=$id; title=$title; reason="no summary/transcript (err=$($note.error))" }
      Write-Host "[$i/$($all.Count)] SKIP (empty): $title"
      continue
    }

    # transcript section
    $sb = New-Object System.Text.StringBuilder
    if ($sentences -and $sentences.Count -gt 0) {
      foreach ($t in $sentences) {
        $ts = MsToTs ([long]$t.beginTime)
        $sp = if ($t.speaker) { "**$($t.speaker):** " } else { '' }
        $sent = ($t.sentence).Trim()
        [void]$sb.Append("`n**[$ts]** $sp$sent`n")
      }
    } else {
      [void]$sb.Append("`n_No transcript available._`n")
    }
    $transcript = $sb.ToString()

    # frontmatter
    $dateIso = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$d.createTime).ToString("yyyy-MM-ddTHH:mm:ssK")
    $tagList = @()
    if ($d.tags) { $tagList = ($d.tags -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
    $tagYaml = if ($tagList.Count -gt 0) { "tags:`n" + (($tagList | ForEach-Object { '  - ' + ($_ | ConvertTo-Json) }) -join "`n") } else { 'tags: []' }
    $titleEsc = ($d.title -replace '"','\"')
    $fm = @(
      '---',
      "title: `"$titleEsc`"",
      "date: $dateIso",
      'source: HiNotes',
      "hidock_id: `"$($d.id)`"",
      "type: $(if($d.type){$d.type}else{'note'})",
      $tagYaml,
      '---',
      ''
    ) -join "`n"

    $bodyMd = if ($md) { $md } else { '_No summary available._' }
    $fileText = $fm + $bodyMd + "`n`n## " + [char]0xD83C + [char]0xDF99 + [char]0xFE0F + " Transcript`n" + $transcript

    $fname = (Sanitize $title) + '.md'
    $path = Join-Path $OutDir $fname
    if (Test-Path $path) { $path = Join-Path $OutDir ((Sanitize $title) + "-$id.md") }
    [System.IO.File]::WriteAllText($path, $fileText, (New-Object System.Text.UTF8Encoding($false)))
    $written++
    Write-Host "[$i/$($all.Count)] OK: $fname"
  }
  catch {
    $skipped += [pscustomobject]@{ id=$id; title=$title; reason="error: $($_.Exception.Message)" }
    Write-Host "[$i/$($all.Count)] ERROR: $title -> $($_.Exception.Message)"
  }
}

Write-Host ""
Write-Host "=== DONE. Written: $written, Skipped: $($skipped.Count) ==="
if ($skipped.Count -gt 0) {
  $skipped | ForEach-Object { "$($_.id)`t$($_.title)`t$($_.reason)" } | Set-Content (Join-Path $OutDir '_skipped.log') -Encoding UTF8
  Write-Host "Skipped list -> $(Join-Path $OutDir '_skipped.log')"
}
