<#
 Installe et lance l'orchestration pour un repo cible (ex. ton appli WPF).
   .\scripts\setup.ps1                      -> demande l'URL du repo
   .\scripts\setup.ps1 -LaunchOnly          -> relance seulement (VS Code + watchers + monitor)
 Crée 3 copies du repo cible dans BaseDir : <nom>-B (Architecte), <nom>-C (Développeur), <nom>-M (monitor).
#>
param(
  [string]$RepoUrl,
  [string]$BaseDir,
  [string]$Branch,
  [ValidateSet('inject', 'auto', 'notify')][string]$Mode = 'inject',
  [switch]$LaunchOnly,
  [switch]$NoLaunch,
  [switch]$Yes
)
. (Join-Path $PSScriptRoot 'lib.ps1')
$Toolkit = Split-Path -Parent $PSScriptRoot
$Tpl = Join-Path $Toolkit 'templates'
if (-not $BaseDir) { $BaseDir = Join-Path $HOME 'orchestrator' }
$cfgPath = Join-Path $BaseDir 'orchestrator.json'
$saved = Read-Json $cfgPath
if ($saved) {
  if (-not $RepoUrl) { $RepoUrl = $saved.repoUrl }
  if (-not $Branch) { $Branch = $saved.branch }
}
if (-not $RepoUrl) { $RepoUrl = Read-Host 'URL du repo Git de ton projet' }
if (-not $Branch) {
  $Branch = Read-Host 'Branche partagée entre A, B et C (Entrée = main)'
  if (-not $Branch) { $Branch = 'main' }
}
$name = ($RepoUrl.TrimEnd('/') -split '[/:]')[-1] -replace '\.git$', ''
$dirs = @{ B = (Join-Path $BaseDir "$name-B"); C = (Join-Path $BaseDir "$name-C"); M = (Join-Path $BaseDir "$name-M") }

# --- Prérequis ---------------------------------------------------------
foreach ($cmd in 'git', 'claude') {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { Write-Log 'setup' "'$cmd' introuvable dans le PATH." Red; exit 1 }
}
$hasCode = [bool](Get-Command code -ErrorAction SilentlyContinue)
if (-not $hasCode) { Write-Log 'setup' "'code' (VS Code) introuvable : les fenêtres VS Code ne seront pas ouvertes." Yellow }

function Ensure-Clone([string]$Dir) {
  if (Test-Path (Join-Path $Dir '.git')) {
    Invoke-Git $Dir @('fetch', '-q') | Out-Null
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dir) | Out-Null
    $r = Invoke-Git (Split-Path -Parent $Dir) @('clone', '-q', $RepoUrl, $Dir)
    if ($r.Code -ne 0) { Write-Log 'setup' "Clone impossible : $($r.Out)" Red; exit 1 }
  }
  if ((Invoke-Git $Dir @('checkout', '-q', $Branch)).Code -ne 0) {
    Invoke-Git $Dir @('checkout', '-q', '-b', $Branch) | Out-Null
  }
  Invoke-Git $Dir @('pull', '--rebase', '--autostash', '-q') | Out-Null
}

function Add-Exclude([string]$Dir, [string[]]$Lines) {
  $f = Join-Path $Dir '.git\info\exclude'
  $cur = ''
  if (Test-Path $f) { $cur = Get-Content -Raw $f }
  foreach ($l in $Lines) { if ($cur -notmatch [regex]::Escape($l)) { Add-Content -Path $f -Value $l } }
}

# --- Inspection + création de la structure (copie B) -------------------
function Install-Scaffold([string]$Dir) {
  $created = New-Object System.Collections.Generic.List[string]
  foreach ($d in 'tasks', 'specs', 'reports') {
    $p = Join-Path $Dir $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null; $created.Add("$d/") }
    if (-not (Get-ChildItem $p -Force -ErrorAction SilentlyContinue)) { Write-Utf8 (Join-Path $p '.gitkeep') ''; $created.Add("$d/.gitkeep") }
  }
  Get-ChildItem $Tpl -Recurse -File | Where-Object { $_.Name -ne 'CLAUDE.md' } | ForEach-Object {
    $rel = $_.FullName.Substring($Tpl.Length + 1)
    $dest = Join-Path $Dir $rel
    if (-not (Test-Path $dest)) {
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
      Copy-Item $_.FullName $dest
      $created.Add($rel.Replace('\', '/'))
    }
  }
  $claude = Join-Path $Dir 'CLAUDE.md'
  $block = Get-Content -Raw -Encoding UTF8 (Join-Path $Tpl 'CLAUDE.md')
  if (-not (Test-Path $claude)) { Write-Utf8 $claude $block; $created.Add('CLAUDE.md') }
  elseif ((Get-Content -Raw -Encoding UTF8 $claude) -notmatch 'orchestrator-ia') {
    Add-Content -Path $claude -Encoding UTF8 -Value ("`n" + $block); $created.Add('CLAUDE.md (bloc ajouté)')
  }
  $gi = Join-Path $Dir '.gitignore'
  $giCur = ''
  if (Test-Path $gi) { $giCur = Get-Content -Raw $gi }
  foreach ($l in 'bin/', 'obj/', '.vs/', '*.user') {
    if ($giCur -notmatch ('(?m)^' + [regex]::Escape($l) + '\s*$')) { Add-Content -Path $gi -Value $l; $created.Add(".gitignore +$l") }
  }
  # horodater state/budget neufs
  $created
}

function Show-Inspection([string]$Dir) {
  $br = (Invoke-Git $Dir @('rev-parse', '--abbrev-ref', 'HEAD')).Out
  $n = (Invoke-Git $Dir @('rev-list', '--count', 'HEAD')).Out
  Write-Log 'setup' "Repo : $name, branche $br, $n commit(s)." Cyan
  $top = @(Get-ChildItem $Dir -Force | Where-Object { $_.Name -ne '.git' } | ForEach-Object { $_.Name })
  if ($top.Count -eq 0) { Write-Log 'setup' 'Repo vide.' Yellow } else { Write-Log 'setup' ('Contenu : ' + ($top -join ', ')) }
  $sln = @(Get-ChildItem $Dir -Recurse -Include *.sln, *.csproj -File -ErrorAction SilentlyContinue | Select-Object -First 3)
  if ($sln.Count -gt 0) { Write-Log 'setup' ('Projet .NET détecté : ' + (($sln | ForEach-Object { $_.Name }) -join ', ')) Green }
  else { Write-Log 'setup' 'Aucun projet .NET (.sln/.csproj) pour l''instant.' Yellow }
}

if (-not $LaunchOnly) {
  Write-Log 'setup' "Préparation de $RepoUrl (branche $Branch) dans $BaseDir"
  Ensure-Clone $dirs.B
  Show-Inspection $dirs.B
  $created = @(Install-Scaffold $dirs.B)
  if ($created.Count -gt 0) {
    Write-Log 'setup' 'À créer / ajouter dans le repo :' Yellow
    $created | ForEach-Object { Write-Host "   + $_" }
    $ok = $Yes
    if (-not $ok) { $ok = ((Read-Host 'Commit et push de cette structure ? (o/N)') -match '^[oOyY]') }
    if ($ok) {
      Invoke-Git $dirs.B @('add', '-A') | Out-Null
      Invoke-Git $dirs.B @('commit', '-q', '-m', 'chore: structure d''orchestration (rôles, protocole, quota)') | Out-Null
      $p = Invoke-Git $dirs.B @('push', '-u', 'origin', $Branch)
      if ($p.Code -ne 0) { Write-Log 'setup' "Push échoué : $($p.Out)" Red; exit 1 }
    } else {
      Write-Log 'setup' 'Structure non commitée : abandon.' Red; exit 1
    }
  } else {
    Write-Log 'setup' 'Structure déjà en place.' Green
  }
  Ensure-Clone $dirs.C
  Ensure-Clone $dirs.M
  Write-Utf8 $cfgPath ((@{ repoUrl = $RepoUrl; branch = $Branch; mode = $Mode } | ConvertTo-Json) + "`n")
}

# --- Fichiers locaux par rôle (non versionnés) --------------------------
$roleInfo = @{
  B = @{ File = 'roles/B-architecte.md';  Model = 'opus';   Label = 'Architecte' }
  C = @{ File = 'roles/C-developpeur.md'; Model = 'sonnet'; Label = 'Developpeur' }
}
foreach ($r in 'B', 'C') {
  $d = $dirs[$r]; $i = $roleInfo[$r]
  Write-Utf8 (Join-Path $d 'CLAUDE.local.md') ("# Rôle dans cette copie : $r ($($i.Label))`n`n@$($i.File)`n")
  $watch = Join-Path $PSScriptRoot 'watch.ps1'
  $tasksPath = Join-Path $d '.vscode\tasks.json'
  $tracked = (Invoke-Git $d @('ls-files', '--error-unmatch', '.vscode/tasks.json')).Code -eq 0
  $mine = (Test-Path $tasksPath) -and ((Get-Content -Raw $tasksPath) -match 'orchestrator-ia')
  if ($tracked -or ((Test-Path $tasksPath) -and -not $mine)) {
    Write-Log 'setup' ".vscode/tasks.json existe déjà dans $d : non modifié (lance watch.ps1 à la main)." Yellow
  } else {
    $cmdClaude = "claude --model $($i.Model) ""Applique ton role defini dans CLAUDE.local.md, puis attends les instructions."""
    $cmdWatch = "powershell -NoProfile -ExecutionPolicy Bypass -File ""$watch"" -RepoDir ""`${workspaceFolder}"" -Role $r -Mode $Mode"
    $tasks = [ordered]@{
      version = '2.0.0'
      '//' = 'orchestrator-ia'
      tasks = @(
        [ordered]@{ label = "Claude $r"; type = 'shell'; command = $cmdClaude; isBackground = $true
          presentation = @{ group = 'orchestrator'; panel = 'dedicated' }; runOptions = @{ runOn = 'folderOpen' }; problemMatcher = @() },
        [ordered]@{ label = "Watcher $r"; type = 'shell'; command = $cmdWatch; isBackground = $true
          presentation = @{ group = 'orchestrator'; panel = 'dedicated' }; runOptions = @{ runOn = 'folderOpen' }; problemMatcher = @() }
      )
    }
    Write-Utf8 $tasksPath (($tasks | ConvertTo-Json -Depth 6) + "`n")
  }
  Add-Exclude $d @('CLAUDE.local.md', '.vscode/tasks.json')
}

# --- Lancement -----------------------------------------------------------
if ($NoLaunch) { Write-Log 'setup' 'Prêt (lancement ignoré).' Green; exit 0 }
if ($hasCode) {
  $ext = Join-Path $Toolkit 'vscode-extension'
  & code -n --extensionDevelopmentPath $ext $dirs.B
  & code -n --extensionDevelopmentPath $ext $dirs.C
  Write-Log 'setup' 'VS Code ouvert sur B et C (extension Orchestrator Bridge chargée). À la première ouverture, autorise « Allow Automatic Tasks » : Claude et le watcher démarrent alors tout seuls dans le terminal.' Green
}
$mon = Join-Path $PSScriptRoot 'monitor.ps1'
Start-Process powershell -ArgumentList @('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$mon`"", '-RepoDir', "`"$($dirs.M)`"")
Write-Log 'setup' 'Fenêtre monitor ouverte : saisis le quota (touche b) avant de démarrer le travail.' Green
Write-Log 'setup' "Côté cloud : dis à la session A de travailler sur la branche '$Branch' de $RepoUrl et de suivre roles/A-orchestrateur.md." Cyan
