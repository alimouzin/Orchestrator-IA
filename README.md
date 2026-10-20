# Orchestrator-IA (boîte à outils)

Ce repo ne contient **que** l'outillage pour orchestrer 3 agents Claude Code : scripts et modèles. Le projet à développer (ici une appli WPF) vit dans un **autre** repo, que `setup.ps1` te demande.

| Agent | Où | Modèle | Rôle |
|---|---|---|---|
| **A** Orchestrateur | Claude Code cloud | Sonnet | Dialogue avec toi, brief, tâches, suivi du quota |
| **B** Architecte | VS Code Windows | Opus | Specs détaillées |
| **C** Développeur | VS Code Windows | Sonnet | Code WPF/C#, exécution, tests, clics |

## Utilisation (Windows, PowerShell)

Prérequis : `git`, `claude` (Claude Code CLI) et `code` (VS Code) dans le PATH.

```powershell
git clone <ce repo> ; cd Orchestrator-IA
.\scripts\setup.ps1            # demande l'URL du repo cible
.\scripts\setup.ps1 -LaunchOnly  # relance plus tard sans réinstaller
```

`setup.ps1` :
1. clone le repo cible 3 fois dans `~\orchestrator` (`-B`, `-C`, `-M`) et en affiche le contenu (branche, fichiers, projet .NET détecté) ;
2. ajoute ce qui manque (dossiers `tasks/ specs/ reports/`, `CLAUDE.md`, `roles/`, `docs/`, `state.json`, `budget.json`, `brief.md`) puis commit/push après confirmation ;
3. crée dans B et C un `CLAUDE.local.md` (rôle, non versionné) et un `.vscode/tasks.json` ;
4. ouvre VS Code sur B et C (accepte « Allow Automatic Tasks » la première fois : Claude et le watcher démarrent dans le terminal) ;
5. ouvre la fenêtre **monitor**.

## Scripts

- `watch.ps1 -Role B|C` : boucle `git pull`, lit le quota, détecte les tâches du rôle et lance `claude -p --model opus|sonnet` (`-Mode auto`) ou copie le prompt dans le presse-papiers (`-Mode notify`). Deux essais max par tâche/statut.
- `monitor.ps1` : tableau de bord (état, tâches, quota). Touche `b` pour saisir les pourcentages de `/usage`; il publie `budget.json`.

## Quota

Seuils (réserve ≈ 10 %) : < 70 % normal ; 70-85 % plus de travail Opus ; 85-90 % rien de nouveau ; ≥ 90 % arrêt. Les chiffres viennent de `/usage` saisi à la main (impossible à lire automatiquement) ; s'ils ont plus de 2 h, les watchers attendent.

## À savoir

- Non testé sur une vraie machine Windows : les scripts sont écrits pour PowerShell 5.1+ ; à valider au premier lancement.
- Le watcher en mode `auto` lance des sessions Claude **non interactives** à côté de la session ouverte dans VS Code. Ne donne pas de travail à la session ouverte pendant ce temps, ou utilise `-Mode notify`.
- Le computer use (clics) n'est a priori pas disponible en mode non interactif : pour la validation visuelle par C, utilise la session ouverte.
- Côté cloud, la session A doit travailler sur la même branche que celle choisie dans `setup.ps1`.
