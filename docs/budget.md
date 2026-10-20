# Surveillance du quota (plan Pro)

Le quota est celui de l'abonnement (fenêtre de session + plafond hebdomadaire), partagé entre **toutes** les sessions du compte. Les agents ne peuvent pas le lire eux-mêmes depuis le cloud : l'utilisateur le relève avec `/usage` (dans Claude Code) et le publie avec `scripts/set-budget.ps1`.

## `budget.json`

```
{ "session_pct": 0, "week_pct": 0, "updated": "" }
```

## Règles (réserve ≈ 10 % pour les urgences)

| Utilisation (max de session_pct / week_pct) | Comportement |
|---|---|
| < 70 % | Normal |
| 70 – 85 % | Pas de nouvelle spec Opus ; tâches courtes seulement |
| 85 – 90 % | Finir la tâche en cours, ne rien démarrer, prévenir l'utilisateur |
| ≥ 90 % | `state.json.status = "paused_budget"` ; tout le monde s'arrête après l'étape courante |

Si `updated` a plus de 2 h, ou si `budget.json` est vide, les agents demandent à l'utilisateur de rafraîchir le chiffre avant de lancer du travail lourd.

## Économies (important en Pro)

- Opus (B) uniquement pour les specs : une spec par module, courte et précise. Jamais pour du code.
- Tâches petites : une session qui repart d'un contexte propre coûte moins qu'un historique géant (`/clear` entre les tâches).
- Pas de computer use en boucle : il est lent et coûteux. Préférer les tests automatisés (UI Automation / FlaUI) et réserver les clics à la vérification finale d'un écran.
- Rapports concis.
