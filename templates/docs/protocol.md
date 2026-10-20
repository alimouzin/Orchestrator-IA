# Protocole d'échange

Un seul écrivain par fichier, pour éviter les conflits Git.

| Fichier | Écrivain | Lecteurs |
|---|---|---|
| `brief.md`, `tasks/T-NNN.md`, `state.json` | A | B, C |
| `specs/*.md` | B | A, C |
| `reports/T-NNN.md`, `src/**` | C | A, B |
| `budget.json` | le moniteur (saisi par l'utilisateur) | A, B, C |

Chaque agent fait `git pull --rebase` avant d'agir et `git push` après chaque livrable.

## Phases (`state.json.phase`)

`cadrage` → `specs` → `validation_specs` → `implementation` → `livraison`
Statuts spéciaux : `paused_budget`, `blocked`.

## Cycle d'une tâche

1. A crée `tasks/T-NNN.md` (objectif, spec liée, critères d'acceptation) et met `state.json.current_task`.
2. Si la spec manque : A met `status: "needs_spec"`, B écrit `specs/<module>.md`, passe `status: "spec_ready"`.
3. C lit la tâche + la spec, code dans `src/`, build, teste, vérifie à l'écran si nécessaire.
4. C écrit `reports/T-NNN.md` (fait / pas fait / commandes lancées / résultat des tests / captures décrites) et met `status: "done"` ou `"failed"`.
5. Échec 3 fois de suite ou spec ambiguë : C met `status: "needs_spec_fix"` et décrit le problème, B amende la spec.
6. A relit le rapport, passe à la tâche suivante ou te fait un point.

## Format d'une tâche (`tasks/T-NNN.md`)

```
---
id: T-001
status: todo   # todo | needs_spec | spec_ready | in_progress | done | failed | needs_spec_fix
spec: specs/xxx.md
---
# Titre
## Objectif
## Critères d'acceptation
## Hors périmètre
```

## state.json

```
{ "phase": "cadrage", "current_task": null, "status": "ok", "updated": "" }
```
