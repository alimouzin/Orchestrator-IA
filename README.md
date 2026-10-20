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

- `watch.ps1 -Role B|C` : boucle `git pull`, lit le quota, détecte les tâches du rôle puis, selon `-Mode` :
  - `inject` (défaut) : dépose un message dans `.git\orchestrator-inbox` ; l'extension `vscode-extension/` (chargée par `code --extensionDevelopmentPath`) le **tape dans le terminal « Claude B/C »** de VS Code : `/clear`, puis le prompt, Entrée envoyée séparément. C'est la session ouverte qui travaille (computer use possible pour C) ;
  - `auto` : lance `claude -p --model opus|sonnet` en non interactif ;
  - `notify` : copie le prompt dans le presse-papiers.
  Renvoi après 25 min sans changement de statut, 2 essais max par tâche/statut.
- `monitor.ps1` : tableau de bord (état, tâches, quota). Touche `b` pour saisir les pourcentages de `/usage`; il publie `budget.json`.

## Pause

Dans la fenêtre **monitor** : `p` pause douce (rien de nouveau, les agents finissent leur étape), `x` pause + arrêt immédiat (envoie Échap aux sessions Claude de B et C puis leur demande de commiter leur état), `r` reprendre. La pause est écrite dans `control.json` (vue par A dans le cloud et par les watchers après `git pull`) et dans un fichier-drapeau local `~\orchestrator\orchestrator.pause` (effet immédiat sur ce PC). Tu peux aussi dire « mets en pause » à A, qui modifie `control.json`.

## Quota

Seuils (réserve ≈ 10 %) : < 70 % normal ; 70-85 % plus de travail Opus ; 85-90 % rien de nouveau ; ≥ 90 % arrêt. Les chiffres viennent de `/usage` saisi à la main (impossible à lire automatiquement) ; s'ils ont plus de 2 h, les watchers attendent.

## À savoir

- Non testé sur une vraie machine Windows : les scripts sont écrits pour PowerShell 5.1+ ; à valider au premier lancement.
- Mode `inject` : le watcher ne sait pas si Claude est occupé. Il attend 20 s avant d'envoyer, puis ne renvoie rien tant que le statut n'a pas changé (25 min). Si tu parles toi-même à la session au même moment, les messages se mélangent.
- Le terminal Claude doit s'appeler « Claude B » / « Claude C » (c'est le nom de la tâche créée par `setup.ps1`) ; sinon l'extension affiche un avertissement.
- Mode `auto` : sessions non interactives, computer use a priori indisponible.
- Côté cloud, la session A doit travailler sur la même branche que celle choisie dans `setup.ps1`.
