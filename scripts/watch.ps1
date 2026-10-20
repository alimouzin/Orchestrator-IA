<#
 Surveille le repo pour un rôle (B ou C) : git pull, quota, nouvelles tâches.
 -Mode inject (défaut) : dépose le message dans .git\orchestrator-inbox ; l'extension « Orchestrator Bridge »
                         le tape dans la session Claude ouverte dans VS Code (comme toi au clavier).
 -Mode auto            : lance `claude -p` (non interactif) avec le bon modèle.
 -Mode notify          : copie le prompt dans le presse-papiers.
#>
param(
  [Parameter(Mandatory)][string]$RepoDir,
  [Parameter(Mandatory)][ValidateSet('B', 'C')][string]$Role,
  [ValidateSet('inject', 'auto', 'notify')][string]$Mode = 'inject',
  [int]$IntervalSec = 60,
  [int]$MaxAttempts = 2,
  [int]$RetryAfterMin = 25,
  [int]$SettleSec = 20,
  [bool]$ClearFirst = $true,
  [string]$ExtraTools = '',
  [switch]$Once
)
. (Join-Path $PSScriptRoot 'lib.ps1')

$roles = @{
  B = @{ Model = 'opus';   File = 'roles/B-architecte.md';  Statuses = @('needs_spec', 'needs_spec_fix'); Tools = 'Read,Write,Edit,Glob,Grep,Bash(git:*)' }
  C = @{ Model = 'sonnet'; File = 'roles/C-developpeur.md'; Statuses = @('spec_ready');                    Tools = 'Read,Write,Edit,Glob,Grep,Bash(git:*),Bash(dotnet:*)' }
}
$cfg = $roles[$Role]
$tools = $cfg.Tools
if ($ExtraTools) { $tools = "$tools,$ExtraTools" }
$tag = "watch-$Role"
$stateFile = Join-Path $RepoDir ".git\orchestrator-$Role.json"
$inbox = Join-Path $RepoDir '.git\orchestrator-inbox'

# jobs[clé] = @{ n = nb d'envois ; t = dernier envoi (UTC, ISO) }
$jobs = @{}
$saved = Read-Json $stateFile
if ($saved) { $saved.PSObject.Properties | ForEach-Object { $jobs[$_.Name] = @{ n = [int]$_.Value.n; t = [string]$_.Value.t } } }
function Save-Jobs { Write-Utf8 $stateFile ($jobs | ConvertTo-Json) }

Write-Log $tag "Surveillance du rôle $Role ($($cfg.Model)) dans $RepoDir (mode $Mode)" Cyan
$script:lastMsg = ''
function Say([string]$m, [string]$c = 'Gray') { if ($m -ne $script:lastMsg) { Write-Log $tag $m $c; $script:lastMsg = $m } }

while ($true) {
  $pull = Sync-Repo $RepoDir
  if ($pull.Code -ne 0) {
    Say "git pull a échoué : $($pull.Out)" Red
  } else {
    $state = Read-Json (Join-Path $RepoDir 'state.json')
    $budget = Get-Budget $RepoDir
    $dec = Get-BudgetDecision $budget $Role
    if ($state -and $state.status -eq 'paused_budget') {
      Say 'Pause décidée par A (paused_budget).' Yellow
    } elseif ($dec -eq 'stale') {
      Say 'Quota inconnu ou périmé : saisis-le dans la fenêtre monitor (touche b).' Yellow
    } elseif ($dec -eq 'stop') {
      Say "Quota à $($budget.Max) % : arrêt (réserve 10 %)." Red
    } elseif ($dec -eq 'hold') {
      Say "Quota à $($budget.Max) % : aucune nouvelle tâche pour $Role." Yellow
    } else {
      $job = Get-Tasks $RepoDir | Where-Object { $cfg.Statuses -contains $_.Status } | Select-Object -First 1
      if (-not $job) {
        Say "Quota $($budget.Max) % ok. Rien à faire." DarkGray
      } else {
        $key = "$($job.Id):$($job.Status)"
        $n = 0; $ageMin = [double]::PositiveInfinity
        if ($jobs.ContainsKey($key)) {
          $n = $jobs[$key].n
          try { $ageMin = ((Get-Date).ToUniversalTime() - [DateTime]::Parse($jobs[$key].t, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal)).TotalMinutes } catch { }
        }
        if ($n -gt 0 -and $ageMin -lt $RetryAfterMin -and $Mode -ne 'auto') {
          Say "$key : envoyé il y a $([int]$ageMin) min, en attente du résultat de Claude." DarkGray
        } elseif ($n -ge $MaxAttempts) {
          Say "$key : $n essais sans changement de statut, intervention requise." Red
        } else {
          $jobs[$key] = @{ n = $n + 1; t = (Get-Date).ToUniversalTime().ToString('o') }
          Save-Jobs
          $prompt = "Tu es le rôle $Role. Lis $($cfg.File) et docs/protocol.md, puis traite $($job.Rel) (statut actuel : $($job.Status)). Mets à jour le statut de la tâche comme décrit dans le protocole, puis fais git add, commit et git push. Reste concis."
          if ($Mode -eq 'inject') {
            Write-Log $tag "Tâche $key : envoi dans $SettleSec s (laisse Claude finir ce qu'il fait)..." Green
            Start-Sleep -Seconds $SettleSec
            New-Item -ItemType Directory -Force -Path $inbox | Out-Null
            $lines = @()
            if ($ClearFirst) { $lines += '/clear' }
            $lines += ($prompt -replace '\s+', ' ')
            $name = (Get-Date).ToString('yyyyMMddHHmmssfff')
            Write-Utf8 (Join-Path $inbox "$name.tmp") ($lines -join "`n")
            Move-Item (Join-Path $inbox "$name.tmp") (Join-Path $inbox "$name.txt")
            Write-Log $tag "Message déposé ($($cfg.Model), essai $($n + 1)/$MaxAttempts) : l'extension le tape dans le terminal Claude." Green
          } elseif ($Mode -eq 'notify') {
            Set-Clipboard -Value $prompt
            [Console]::Beep(800, 300)
            Write-Log $tag "Tâche $key prête. Prompt copié : colle-le dans la session Claude ($($cfg.Model))." Green
          } else {
            Write-Log $tag "Lancement de claude -p ($($cfg.Model)) sur $key (essai $($n + 1)/$MaxAttempts)" Green
            Push-Location $RepoDir
            & claude -p $prompt --model $cfg.Model --permission-mode acceptEdits --allowedTools $tools
            $code = $LASTEXITCODE
            Pop-Location
            Write-Log $tag "claude terminé (code $code)" Gray
            if ((Invoke-Git $RepoDir @('status', '-sb')).Out -match 'ahead') { Push-Repo $RepoDir | Out-Null }
          }
          $script:lastMsg = ''
        }
      }
    }
  }
  if ($Once) { break }
  Start-Sleep -Seconds $IntervalSec
}
