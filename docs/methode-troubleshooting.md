# Méthode de troubleshooting

## Les étapes

1. **Observer** : symptôme exact, depuis quand, qui est touché, qu'est-ce qui a changé récemment.
2. **Éliminer couche par couche** : interface → passerelle → réseau par IP → DNS → service → droits. Ne passer à la couche suivante que si la précédente est validée.
3. **Comparer** : ce qui fonctionne et ce qui ne fonctionne pas (deux utilisateurs, deux postes, avant / après).
4. **Lire les journaux** : ils contiennent souvent la cause exacte (`journalctl`, `NetSetup.LOG`, Observateur d'événements).
5. **Formuler une hypothèse et la vérifier** avant d'agir. Une hypothèse plausible n'est pas une cause.
6. **Corriger la cause, pas le symptôme.**
7. **Vérifier** que la correction fonctionne, idéalement en rejouant l'incident.
8. **Documenter** : symptôme, diagnostic, cause, correction, vérification, leçons.

## Réflexes

- Avant chaque commande : **sur quelle machine, sous quel compte ?** (lire le prompt).
- Avant toute action destructrice ou irréversible : vérifier, lire, **puis** agir.
- Tester une configuration avant de recharger un service : `sshd -t &&`, `nginx -t &&`.
- Garder un accès de secours avant de toucher à l'accès distant.
- Regarder **d'où vient** une réponse, pas seulement s'il y en a une (`Data from: synthetic`).
- Corriger la **première** erreur d'une série : les suivantes sont souvent des effets en cascade.
- Préserver les traces d'un comportement anormal avant de nettoyer.

## Exemple : « le site ne répond plus »

| Test | Si OK | Si KO |
|---|---|---|
| Résolution du nom | Passer au réseau | Problème DNS |
| Ping de l'adresse | Passer au service | Réseau, pare-feu ou machine éteinte |
| Port 80 (`Test-NetConnection -Port 80`, `curl`) | Problème applicatif | Service arrêté ou port filtré |
| `systemctl status` + journaux | — | Cause dans le message d'erreur |
