# Fonctions communes aux scripts d'orchestration (à charger avec ". lib.ps1").

function Write-Utf8([string]$Path, [string]$Text) {
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}

function Read-Json([string]$Path) {
  if (-not (Test-Path $Path)) { return $null }
  try { return (Get-Content -Raw -Encoding UTF8 $Path | ConvertFrom-Json) } catch { return $null }
}

function Write-Log([string]$Tag, [string]$Msg, [string]$Color = 'Gray') {
  Write-Host ("{0} [{1}] {2}" -f (Get-Date -Format 'HH:mm:ss'), $Tag, $Msg) -ForegroundColor $Color
}

function Invoke-Git([string]$Dir, [string[]]$GitArgs) {
  $out = & git -C $Dir @GitArgs 2>&1
  [pscustomobject]@{ Code = $LASTEXITCODE; Out = (($out | ForEach-Object { "$_" }) -join "`n") }
}

function Sync-Repo([string]$Dir) {
  $r = Invoke-Git $Dir @('pull', '--rebase', '--autostash', '-q')
  if ($r.Code -ne 0) { Invoke-Git $Dir @('rebase', '--abort') | Out-Null }
  $r
}

function Push-Repo([string]$Dir) {
  $r = Invoke-Git $Dir @('push')
  if ($r.Code -ne 0) {
    Sync-Repo $Dir | Out-Null
    $r = Invoke-Git $Dir @('push')
  }
  $r
}

# --- Quota -------------------------------------------------------------

function Get-Budget([string]$RepoDir) {
  $path = Join-Path $RepoDir 'budget.json'
  $r = [pscustomobject]@{ Session = 0; Week = 0; Max = 0; AgeMin = [double]::PositiveInfinity; Known = $false }
  if (-not (Test-Path $path)) { return $r }
  $raw = Get-Content -Raw -Encoding UTF8 $path
  try {
    $j = $raw | ConvertFrom-Json
    if ($raw -match '"updated"\s*:\s*"([^"]+)"') {
      $t = [DateTimeOffset]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture)
      $r.AgeMin = ((Get-Date).ToUniversalTime() - $t.UtcDateTime).TotalMinutes
      $r.Session = [int]$j.session_pct
      $r.Week = [int]$j.week_pct
      $r.Max = [Math]::Max($r.Session, $r.Week)
      $r.Known = $true
    }
  } catch { }
  $r
}

# Retourne : ok | hold (ne rien démarrer) | stop (tout arrêter) | stale (chiffres périmés)
function Get-BudgetDecision($Budget, [string]$Role, [int]$StaleMin = 120) {
  if (-not $Budget.Known -or $Budget.AgeMin -gt $StaleMin) { return 'stale' }
  if ($Budget.Max -ge 90) { return 'stop' }
  if ($Budget.Max -ge 85) { return 'hold' }
  if ($Role -eq 'B' -and $Budget.Max -ge 70) { return 'hold' }
  'ok'
}

function Set-Budget([string]$RepoDir, [int]$Session, [int]$Week) {
  $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  Write-Utf8 (Join-Path $RepoDir 'budget.json') ("{{ ""session_pct"": {0}, ""week_pct"": {1}, ""updated"": ""{2}"" }}`n" -f $Session, $Week, $now)
  Invoke-Git $RepoDir @('add', 'budget.json') | Out-Null
  Invoke-Git $RepoDir @('commit', '-q', '-m', "budget: session=$Session% week=$Week%") | Out-Null
  Push-Repo $RepoDir
}

# --- Tâches ------------------------------------------------------------

function Get-Tasks([string]$RepoDir) {
  $d = Join-Path $RepoDir 'tasks'
  if (-not (Test-Path $d)) { return @() }
  @(Get-ChildItem $d -Filter 'T-*.md' | Sort-Object Name | ForEach-Object {
    $t = Get-Content -Raw -Encoding UTF8 $_.FullName
    $s = '?'
    if ($t -match '(?m)^status:\s*([A-Za-z_]+)') { $s = $Matches[1] }
    [pscustomobject]@{ Id = $_.BaseName; Status = $s; Rel = "tasks/$($_.Name)" }
  })
}
