# Publie la consommation relevée avec /usage dans Claude Code.
# Usage : .\scripts\set-budget.ps1 -Session 62 -Week 41
param(
  [Parameter(Mandatory)][int]$Session,
  [Parameter(Mandatory)][int]$Week
)
$root = Split-Path -Parent $PSScriptRoot
$json = @{ session_pct = $Session; week_pct = $Week; updated = (Get-Date).ToUniversalTime().ToString("o") } | ConvertTo-Json
Set-Content -Path (Join-Path $root "budget.json") -Value $json -Encoding utf8
git -C $root add budget.json
git -C $root commit -m "budget: session=$Session% week=$Week%"
git -C $root pull --rebase
git -C $root push
