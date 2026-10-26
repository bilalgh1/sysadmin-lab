# Troubleshooting

Chaque fiche suit la même structure : **symptôme → diagnostic → cause racine → correction → vérification → leçons**.

| # | Incident | Type |
|---|---|---|
| [01](01-dns-ntp.md) | `apt` en échec et horloge fausse | Réel |
| [02](02-nginx-sans-relance.md) | Site hors ligne après l'arrêt brutal de Nginx | Provoqué |
| [03](03-mises-a-jour-bloquees-batterie.md) | 56 correctifs de sécurité jamais installés | Réel |
| [04](04-perte-acces-ssh.md) | Perte de l'accès SSH | Réel |
| [05](05-jonction-windows-home.md) | Jonction au domaine refusée | Réel |
| [06](06-compte-verrouille.md) | Compte utilisateur verrouillé | Réel |
| [07](07-disque-plein.md) | Site hors ligne, disque plein | Simulé |
| [08](08-acces-partage-groupe.md) | Utilisateur privé d'accès au partage | Simulé |
| [09](09-relation-approbation.md) | Relation d'approbation rompue | Simulé |

- **Réel** : survenu pendant la construction du lab.
- **Provoqué** : déclenché volontairement pour tester un comportement.
- **Simulé** : exercice de diagnostic sur table (*tabletop*), avec des résultats de commandes simulés ; non reproduit dans le lab.

Méthode commune : [../docs/methode-troubleshooting.md](../docs/methode-troubleshooting.md)
