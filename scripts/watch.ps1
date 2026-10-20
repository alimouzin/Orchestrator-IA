<#
 Surveille le repo pour un rôle (B ou C) : git pull, quota, nouvelles tâches.
 -Mode auto   : lance `claude -p` (non interactif) avec le bon modèle pour traiter la tâche.
 -Mode notify : copie le prompt dans le presse-papiers pour le coller dans la session Claude ouverte.
#>
param(
  [Parameter(Mandatory)][string]$RepoDir,
  [Parameter(Mandatory)][ValidateSet('B', 'C')][string]$Role,
  [ValidateSet('auto', 'notify')][string]$Mode = 'auto',
  [int]$IntervalSec = 60,
  [int]$MaxAttempts = 2,
  [string]$ExtraTools = '',
  [switch]$Once
)
. (Join-Path $PSScriptRoot 'lib.ps1')

$roles = @{
  B = @{ Model = 'opus';   File = 'roles/B-architecte.md';   Statuses = @('needs_spec', 'needs_spec_fix'); Tools = 'Read,Write,Edit,Glob,Grep,Bash(git:*)' }
  C = @{ Model = 'sonnet'; File = 'roles/C-developpeur.md';  Statuses = @('spec_ready');                    Tools = 'Read,Write,Edit,Glob,Grep,Bash(git:*),Bash(dotnet:*)' }
}
$cfg = $roles[$Role]
$tools = $cfg.Tools
if ($ExtraTools) { $tools = "$tools,$ExtraTools" }
$tag = "watch-$Role"
$attemptsFile = Join-Path $RepoDir ".git\orchestrator-$Role.json"
$attempts = @{}
$saved = Read-Json $attemptsFile
if ($saved) { $saved.PSObject.Properties | ForEach-Object { $attempts[$_.Name] = [int]$_.Value } }

Write-Log $tag "Surveillance du rôle $Role ($($cfg.Model)) dans $RepoDir (mode $Mode)" Cyan
$lastMsg = ''
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
      Say "Pause décidée par A (paused_budget)." Yellow
    } elseif ($dec -eq 'stale') {
      Say "Quota inconnu ou périmé : saisis-le dans la fenêtre monitor (touche b)." Yellow
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
        $n = 0
        if ($attempts.ContainsKey($key)) { $n = $attempts[$key] }
        if ($n -ge $MaxAttempts) {
          Say "$key : $n essais sans changement de statut, intervention requise." Red
        } else {
          $attempts[$key] = $n + 1
          Write-Utf8 $attemptsFile ($attempts | ConvertTo-Json)
          $prompt = "Tu es le rôle $Role. Lis $($cfg.File) et docs/protocol.md, puis traite $($job.Rel) (statut actuel : $($job.Status)). Mets à jour le statut de la tâche comme décrit dans le protocole, puis fais git add, commit et git push. Reste concis."
          if ($Mode -eq 'notify') {
            Set-Clipboard -Value $prompt
            [Console]::Beep(800, 300)
            Write-Log $tag "Tâche $key prête. Prompt copié : colle-le dans la session Claude ($($cfg.Model))." Green
            $attempts[$key] = $MaxAttempts
            Write-Utf8 $attemptsFile ($attempts | ConvertTo-Json)
          } else {
            Write-Log $tag "Lancement de claude ($($cfg.Model)) sur $key (essai $($n + 1)/$MaxAttempts)" Green
            Push-Location $RepoDir
            & claude -p $prompt --model $cfg.Model --permission-mode acceptEdits --allowedTools $tools
            $code = $LASTEXITCODE
            Pop-Location
            Write-Log $tag "claude terminé (code $code)" Gray
            $ahead = Invoke-Git $RepoDir @('status', '-sb')
            if ($ahead.Out -match 'ahead') { Push-Repo $RepoDir | Out-Null }
            $lastMsg = ''
          }
        }
      }
    }
  }
  if ($Once) { break }
  Start-Sleep -Seconds $IntervalSec
}
