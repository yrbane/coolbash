# Changelog

## 0.2.1 — 2026-09-07 · « CI verte : lint des tests »
- shellcheck (niveau info) sur les fichiers de tests : source dynamique de `lib.sh` (SC1091),
  `ls | wc -l` remplacé par `find` (SC2012), `$HOME` littéral voulu documenté (SC2016).
- Aucun changement fonctionnel.

## 0.2.0 — 2026-09-07 · « Isolation de la CLI et suite de tests »

### Corrigé
- **nvm cassé au démarrage du shell** : la CLI, sourcée par `~/.bashrc`, laissait une variable
  générique `PREFIX` dans le shell, ce que nvm refuse (« nvm is not compatible with the PREFIX
  environment variable »). Toutes les variables sont désormais préfixées `COOLBASH_`, toutes les
  fonctions `coolbash` / `_coolbash_` ; plus de `log`, `error`, `cmd_*` dans le shell utilisateur.
- `make uninstall` supprimait le clone git lui-même quand `PREFIX` pointait dessus : garde-fou ajouté.
- `make uninstall` effaçait toute ligne du `.bashrc` contenant le mot « coolbash » : la suppression
  ne cible plus que la ligne `source … cli/coolbash init`.
- `make install` écrasait `90-local-overrides.bash` (les surcharges de l'utilisateur) à chaque
  mise à jour : le fichier n'est plus jamais écrasé s'il existe.
- `make install` échouait (« same file ») lorsque `PREFIX` était le clone (cas `install.sh`).
- `30-aliases.bash` renvoyait 1 quand `~/.bash_aliases` est absent (`[[ ]] && .` en dernière ligne).
- `install.sh` affichait une variable non définie et pointait sur `yourusername`.
- Les commandes `install/update/verify/uninstall` appelaient `make` dans le répertoire courant :
  elles ciblent maintenant le clone (`make -C`), retrouvé via `COOLBASH_REPO`, le fichier `.repo`
  écrit à l'installation, ou le parent du script.

### Ajouté
- **Suite de tests sans dépendance** (`make test`, `bash tests/run.sh`) : isolation de la CLI
  (diff des variables/fonctions avant/après `init`, reproduction du garde-fou de nvm), commandes de
  la CLI, ordre de chargement des modules, chargement individuel de chaque module, cycle
  `make install / reinstall / uninstall` dans un HOME jetable, syntaxe + shellcheck.
- Commandes `coolbash version` (cohérence testée avec ce CHANGELOG) et `coolbash test`.
- Fonction shell `coolbash` disponible après `init` (le README la promettait déjà).
- CI GitHub Actions (`make test` avec shellcheck) et fichier `LICENSE` (MIT).

### Modifié
- Bannières ASCII des modules rafraîchies.
- Chargement des modules : un module en échec n'interrompt plus les suivants et est signalé.

## 0.1.0 — 2025-10-05 · « Structure initiale »
- Modules, CLI, Makefile, script d'installation.
