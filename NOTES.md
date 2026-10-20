# Notes de reprise (Orchestrator-IA)

## Objectif
Orchestrer 3 agents Claude Code (abonnement **Pro**, pas d'API) pour développer une appli **WPF / C#** :
- **A** Orchestrateur : Sonnet, Claude Code **cloud**. Seul interlocuteur de l'utilisateur.
- **B** Architecte : Opus, VS Code **Windows**. Écrit les specs détaillées.
- **C** Développeur : Sonnet (2e instance), VS Code **Windows**. Code, exécute, teste, clique (computer use).

Ce repo = **boîte à outils uniquement**. Le projet WPF est dans un autre repo, demandé par `setup.ps1`.

## Décisions
- Communication par **fichiers Git** (boîte aux lettres) : `brief.md`, `tasks/T-NNN.md`, `specs/`, `reports/`, `state.json`, `budget.json`, `control.json`. Un seul écrivain par fichier (`docs/protocol.md` dans `templates/`).
- Le cloud ne peut pas joindre le PC : le pont est Git (Remote Control reste à tester).
- Rôles via `CLAUDE.md` (A) et `CLAUDE.local.md` non versionné (B, C) ; `.vscode/tasks.json` lance Claude + watcher à l'ouverture.
- Les agents tapent dans la session VS Code via une **extension locale** (`vscode-extension/`, chargée par `code --extensionDevelopmentPath`) qui lit `.git/orchestrator-inbox/*.txt` et fait `sendText` (texte, pause, Entrée séparée).
- **Quota** : `/usage` n'est pas lisible automatiquement → saisi à la main dans le moniteur (`b`) → `budget.json`. Seuils : <70 % ok ; 70-85 % pas d'Opus ; 85-90 % rien de nouveau ; ≥90 % arrêt. Chiffres périmés (>2 h) : les watchers attendent.
- **Pause** : `control.json` + fichier-drapeau local. Moniteur : `p` douce, `x` immédiate (Échap + ordre de commiter), `r` reprise. A peut aussi la modifier.

## Contenu du repo
- `scripts/setup.ps1` : demande URL + branche, clone B/C/M, inspecte, crée la structure (commit/push après confirmation), fichiers locaux de rôle, ouvre VS Code x2 + monitor. `-LaunchOnly` pour relancer.
- `scripts/watch.ps1 -Role B|C` : pull, quota, pause, détecte les tâches ; modes `inject` (défaut), `auto` (`claude -p`), `notify`.
- `scripts/monitor.ps1` : tableau de bord, quota, pause.
- `scripts/lib.ps1`, `templates/`, `vscode-extension/`, `README.md`.

## À faire / non vérifié (rien n'a été exécuté sur Windows)
1. Lancer `.\scripts\setup.ps1` et corriger les erreurs PowerShell 5.1 éventuelles.
2. Vérifier que le terminal s'appelle bien « Claude B » / « Claude C » et que l'extension tape + valide (sortie « Orchestrator Bridge »).
3. Vérifier que Échap interrompt Claude Code (pause `x`).
4. Tester l'aller-retour avec une tâche bidon (A → B → C → rapport).
5. Tester Remote Control pour que A parle directement aux sessions PC.
6. Brancher la session A cloud sur la branche partagée choisie dans `setup.ps1`.
7. Décider du mode final pour C : `inject` (computer use possible) vs `auto`.

Branche de travail : `claude/sleepy-knuth-8w40it`.
