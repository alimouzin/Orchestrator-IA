<#
 Tableau de bord : état, tâches, quota. Seul écrivain de budget.json.
 Touches : b = saisir le quota (/usage) ; p = pause douce ; x = pause + arrêt immédiat ; r = reprendre ; q = quitter.
#>
param(
  [Parameter(Mandatory)][string]$RepoDir,
  [int]$IntervalSec = 30,
  [int]$StaleMin = 120,
  [string]$PauseFile = '',
  [string]$WorkDirsCsv = ''
)
. (Join-Path $PSScriptRoot 'lib.ps1')

function Read-Pct([string]$Label) {
  while ($true) {
    $v = Read-Host $Label
    if ($v -eq '') { return $null }
    $n = 0
    if ([int]::TryParse($v, [ref]$n) -and $n -ge 0 -and $n -le 100) { return $n }
    Write-Host 'Entre un nombre entre 0 et 100 (ou Entrée pour reporter).' -ForegroundColor Yellow
  }
}

function Ask-Budget {
  Write-Host ''
  Write-Host 'Dans Claude Code, tape /usage puis recopie les pourcentages.' -ForegroundColor Cyan
  $s = Read-Pct 'Session en cours (%)'
  if ($null -eq $s) { return $false }
  $w = Read-Pct 'Semaine (%)'
  if ($null -eq $w) { return $false }
  $r = Set-Budget $RepoDir $s $w
  if ($r.Code -ne 0) { Write-Host "Publication échouée : $($r.Out)" -ForegroundColor Red }
  $true
}

function Set-Pause([bool]$Paused, [bool]$StopNow) {
  $reason = ''
  if ($Paused) {
    $reason = Read-Host 'Raison (Entrée = aucune)'
    if (-not $reason) { $reason = 'demandée par l''utilisateur' }
  }
  $r = Set-Control $RepoDir $PauseFile $Paused $reason
  if ($r.Code -ne 0) { Write-Host "Publication de control.json échouée (pause locale active quand même) : $($r.Out)" -ForegroundColor Red }
  if ($Paused -and $StopNow) {
    $msg = 'PAUSE demandée par l''utilisateur : arrête-toi maintenant. Fais git add, commit et push de l''état actuel, note dans le rapport où tu en es, puis ne fais plus rien tant que control.json indique paused=true.'
    foreach ($d in ($WorkDirsCsv -split ',' | Where-Object { $_ })) { Send-ToClaude $d @('<ESC>', $msg) }
  }
}

$snooze = Get-Date
while ($true) {
  Sync-Repo $RepoDir | Out-Null
  $state = Read-Json (Join-Path $RepoDir 'state.json')
  $b = Get-Budget $RepoDir
  Clear-Host
  Write-Host '=== Orchestrator monitor ===' -ForegroundColor Cyan
  $ctl = Get-Control $RepoDir $PauseFile
  if ($ctl.Paused) { Write-Host ("*** PAUSE *** {0}" -f $ctl.Reason) -ForegroundColor Black -BackgroundColor Yellow }
  if ($state) { Write-Host ("Phase : {0}   Statut : {1}   Tâche : {2}" -f $state.phase, $state.status, $state.current_task) }
  if ($b.Known) {
    $col = 'Green'
    if ($b.Max -ge 70) { $col = 'Yellow' }
    if ($b.Max -ge 85) { $col = 'Red' }
    Write-Host ("Quota : session {0} %   semaine {1} %   (relevé il y a {2:N0} min)" -f $b.Session, $b.Week, $b.AgeMin) -ForegroundColor $col
  } else {
    Write-Host 'Quota : inconnu' -ForegroundColor Yellow
  }
  Write-Host ''
  $tasks = Get-Tasks $RepoDir
  if ($tasks.Count -eq 0) { Write-Host '(aucune tâche)' -ForegroundColor DarkGray }
  else { $tasks | Format-Table Id, Status, Rel -AutoSize | Out-Host }
  Write-Host '[p] pause (fin de l''étape)  [x] pause + arrêt immédiat  [r] reprendre  [b] quota  [q] quitter' -ForegroundColor DarkGray

  if (((-not $b.Known) -or $b.AgeMin -gt $StaleMin) -and (Get-Date) -gt $snooze) {
    if (-not (Ask-Budget)) { $snooze = (Get-Date).AddMinutes(15) }
    continue
  }
  $until = (Get-Date).AddSeconds($IntervalSec)
  while ((Get-Date) -lt $until) {
    if ([Console]::KeyAvailable) {
      $k = [Console]::ReadKey($true)
      if ($k.KeyChar -eq 'q') { return }
      if ($k.KeyChar -eq 'b') { Ask-Budget | Out-Null; break }
      if ($k.KeyChar -eq 'p') { Set-Pause $true $false; break }
      if ($k.KeyChar -eq 'x') { Set-Pause $true $true; break }
      if ($k.KeyChar -eq 'r') { Set-Pause $false $false; break }
    }
    Start-Sleep -Milliseconds 300
  }
}
