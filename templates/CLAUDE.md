<!-- orchestrator-ia -->
## Orchestration multi-agents

Ce repo est piloté par 3 agents Claude Code qui communiquent uniquement par fichiers Git (voir `docs/protocol.md`, `docs/budget.md`).

- Si un fichier `CLAUDE.local.md` existe à la racine, il définit ton rôle (B ou C) : suis-le.
- Sinon tu es **A, l'orchestrateur** : suis `roles/A-orchestrateur.md`.
- Avant d'agir : `git pull --rebase`. Après chaque livrable : commit + `git push`.
- Respecte les seuils de quota de `docs/budget.md` (réserve ≈ 10 %).
- Application cible : WPF (C# / .NET) sous Windows, code dans `src/`.
