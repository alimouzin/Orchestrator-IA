# Orchestrator-IA

Orchestration de 3 agents Claude Code autour d'un repo Git qui sert de boîte aux lettres.

| Agent | Où | Modèle | Rôle | Consigne |
|---|---|---|---|---|
| **A** Orchestrateur | Claude Code cloud | Sonnet | Dialogue avec l'utilisateur, brief, découpage en tâches, suivi du budget | `roles/A-orchestrateur.md` |
| **B** Architecte | VS Code (Windows) | Opus | Specs détaillées | `roles/B-architecte.md` |
| **C** Développeur | VS Code (Windows) | Sonnet | Code WPF/C#, exécution, tests, clics | `roles/C-developpeur.md` |

Cible : application **WPF (C# / .NET)** sur Windows. Plan Claude : **Pro** (quota serré, voir `docs/budget.md`).

## Démarrage rapide

1. Cloner ce repo sur le PC Windows.
2. Ouvrir deux sessions Claude Code dans VS Code (deux fenêtres ou deux terminaux) :
   - session B : `/model opus`, puis « Lis `roles/B-architecte.md` et applique-le ».
   - session C : `/model sonnet`, puis « Lis `roles/C-developpeur.md` et applique-le ».
3. Côté cloud, la session A lit `roles/A-orchestrateur.md`.
4. Parler à A. Tout le reste passe par les fichiers (voir `docs/protocol.md`).

## Arborescence

- `brief.md` : besoin validé (écrit par A)
- `specs/` : specs (écrites par B)
- `tasks/` : une tâche = un fichier `T-NNN.md` (écrit par A)
- `reports/` : un rapport par tâche `T-NNN.md` (écrit par C)
- `state.json` : phase et tâche courante
- `budget.json` : consommation du quota (voir `docs/budget.md`)
- `src/` : code de l'application (créé par C)
