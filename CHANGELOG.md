# Changelog

## 0.6.0 — 2026-09-07 · « Icônes dans le prompt »
### Ajouté
- Icônes Nerd Font devant chaque segment du prompt : utilisateur, host, branche git, venv, durée,
  dossier courant, cadenas pour root. Le tableau `COOLBASH_PROMPT_SYM` existait mais ne
  contenait que des chaînes vides (hors root) : le prompt n'affichait aucune icône.
- `COOLBASH_PROMPT_ICONS` : `nerd` (défaut), `basic` (symboles Unicode standard `⎇ ⚗ ⧗ ⚠`,
  sans police spéciale), `0` (aucune). Résolution par défaut : `0` sur la console (`TERM=linux`),
  `basic` en mode `safe`, `nerd` sinon ; une valeur inconnue retombe sur `basic`.
### Modifié
- Les glyphes Nerd Font sont écrits `$'\uXXXX'` dans le source (lisibles, pas de caractère
  invisible) ; plus d'espace orpheline devant `\u`, `\h` ou `\w` quand l'icône est absente.
- Tests : jeu complet en mode `nerd`, absence de glyphe zone privée en `basic`/`0`, résolution
  du mode (`TERM=linux`, safe, réglage explicite, valeur inconnue).

## 0.5.1 — 2026-09-07 · « Titre unique, tests hermétiques »
- `PS1` ne repose plus le titre du terminal quand la distribution le fait déjà dans
  `PROMPT_COMMAND` (Arch, `/etc/bash.bashrc`) : il était écrit deux fois.
- `tests/test_mode_safe.sh` n'hérite plus de `COOLBASH_MOTD_SHOWN` / `COOLBASH_COMPLETION_LOADED`
  exportés par un CoolBash déjà chargé dans le shell qui lance les tests.

## 0.5.0 — 2026-09-07 · « PS0 utile : heure de départ et titre du terminal »
### Ajouté
- À l'Entrée, `PS0` affiche en gris l'heure réelle de départ de la commande (`  ⏱ 14:32:41`) :
  l'heure du prompt date de son affichage, pas du moment où l'on valide. `COOLBASH_PS0_STAMP=0`.
- `PS0` met la commande en cours dans le titre du terminal (xterm, tmux, screen, alacritty, foot,
  kitty, wezterm…) ; `PS1` remet `user@host: dossier`. `COOLBASH_PS0_TITLE=0`.
- `COOLBASH_PS0_EXTRA` : fragment personnel ajouté à la fin de `PS0`.
### Modifié
- Le top départ du chrono passe par un tableau dédié `COOLBASH_PROMPT_PS0_SINK` au lieu de `$_`.
- Tests : rendu de `PS0` (`${PS0@P}`), titre en shell interactif, absence de `\[ \]` dans `PS0`.

## 0.4.2 — 2026-09-07 · « README à jour »
- README : exemple de prompt avec les nouveaux indicateurs git et la durée en ms, tableau des tests
  complété (`test_prompt`, `test_isolation_modules`, `test_mode_safe`, `test_perf`, `update`, `doctor`).
  Aucun changement de code.

## 0.4.1 — 2026-09-07 · « make update passe par les tests »
- `make update` (et `coolbash update`) enchaîne `git pull --rebase`, `make test`, `make install` :
  une régression tirée du dépôt n'atteint plus le shell. Test : un dépôt jetable avec un test cassé
  fait échouer `update` et rien n'est installé.

## 0.4.0 — 2026-09-07 · « Isolation, doctor, mode safe, modules désactivables »
### Corrigé
- **Historique partagé jamais branché** : `__history_sync` n'était pas dans `PROMPT_COMMAND`, les
  commandes n'étaient écrites qu'à la fermeture du shell. Désormais `_coolbash_history_sync` est
  appelée à chaque prompt (test : la commande est dans `HISTFILE` dès le prompt suivant).
- **Completion jamais chargée** : `_load_completions_safely` n'était appelée nulle part. Remplacée
  par un vrai chargement différé : `complete -D` charge bash-completion, git, composer, symfony,
  fzf au premier `<Tab>` puis se retire (retour 124 = bash relance la completion).
- `GPG_TTY` n'est exporté qu'avec un terminal.
### Modifié
- **Noms isolés dans tous les modules** : fonctions internes préfixées `_coolbash_`
  (`_coolbash_history_sync`, `_coolbash_completion_load`, `_coolbash_motd`…). `log` et `error`,
  qui masquaient des commandes génériques, deviennent `coolbash_log` / `coolbash_error`.
  L'API publique est listée dans le README et verrouillée par `tests/test_isolation_modules.sh`.
- `_coolbash_prompt_command_add` (00-core) : helper commun pour `PROMPT_COMMAND`.
- **`COOLBASH_MODE=safe` réellement appliqué** (root par défaut, forçable) : pas d'emoji, pas de
  git dans le prompt, pas de MOTD, pas de completion différée. `COOLBASH_MOTD_SHOWN` remplace
  `BASHRC_MOTD_SHOWN` ; `COOLBASH_MOTD=0` s'ajoute à `MOTD_DISABLE`.
### Ajouté
- `coolbash doctor` : bash ≥ 4.4, ligne du `.bashrc`, CLI installée, modules, locale (requis, ✘ =
  code 1) ; git, fortune, cowsay, lolcat, neofetch, fzf, dircolors, shellcheck (optionnels).
- `COOLBASH_DISABLE="70-motd 33"` : modules à ne pas charger (nom complet, numéro ou nom).
- README : sections Configuration et API publique.
- Tests : `test_isolation_modules.sh`, `test_mode_safe.sh`, historique, completion, doctor.

## 0.3.1 — 2026-09-07 · « Lint des tests du prompt »
- `SC2016` (info) désactivé au niveau fichier dans `tests/test_*.sh` : les scripts inline en simple
  quotes y sont voulus. Aucun changement fonctionnel. La 0.3.0 n'ayant pas été taguée, cette
  release couvre aussi ses notes.

## 0.3.0 — 2026-09-07 · « Prompt sans trap, git en un appel, budget de démarrage »
### Modifié
- **Durée des commandes sans `trap DEBUG`** : mesure par `PS0` + `EPOCHREALTIME` (bash ≥ 4.4),
  précision à la milliseconde (`1.23s`, `1m05s`), seuil d'affichage `COOLBASH_PROMPT_MIN_MS`
  (défaut 1000). Le trap DEBUG, exécuté à chaque commande, était la source des blocages.
- **Segment git en un seul appel** : `git status --porcelain=v2 --branch` avec
  `GIT_OPTIONAL_LOCKS=0` (ne bloque jamais), au lieu de trois commandes. Nouveaux indicateurs :
  `?` non suivis, `!` conflits, `↑N`/`↓N` avance/retard sur l'upstream, sha court si HEAD détachée.
  Réglages : `COOLBASH_PROMPT_GIT=0`, `COOLBASH_PROMPT_GIT_UNTRACKED=0` (gros dépôts).
- Le module ne définit plus que des noms `COOLBASH_PROMPT_*` / `_coolbash_prompt_*` : fini
  `reset`, `bold`, `blue`, `yellow`, `rgb`, `user_fg`… dans le shell de l'utilisateur.
- Emoji de session forçable ou désactivable via `COOLBASH_PROMPT_EMOJI` (vide = aucun).
### Ajouté
- `tests/test_prompt.sh` : absence de trap, mesure réelle en shell interactif, formatage,
  segment git sur un dépôt jetable (propre, `?`, `*`, `+`, `↑`, détaché), isolation des noms.
- `tests/test_perf.sh` : budget de démarrage de `init` complet (`COOLBASH_TEST_INIT_BUDGET_MS`,
  défaut 200 ms ; mesuré ≈ 20 ms).

## 0.2.4 — 2026-09-07 · « Bannières ASCII partout »
- Bannières ASCII ajoutées aux modules qui n'en avaient pas : `50-prompt`, `60-completion`,
  `90-local-overrides`. En-têtes harmonisés (`# shellcheck shell=bash`, bannière, séparateur, description FR).
- Aucun changement fonctionnel.

## 0.2.3 — 2026-09-07 · « Lint des tests (suite) »
- shellcheck (info) sur `tests/test_modules.sh` : SC2016, SC2018, SC2019. Aucun changement fonctionnel.

## 0.2.2 — 2026-09-07 · « Portabilité : locale et vérification de syntaxe »
- `00-core.bash` imposait `LC_ALL=fr_FR.UTF-8` même sans cette locale (serveurs, CI) :
  « setlocale: cannot change locale ». Repli sur `C.UTF-8` quand `fr_FR.UTF-8` est absente ;
  une valeur déjà définie n'est jamais modifiée. Test ajouté.
- `make verify` : `bash -n a b c` ne vérifie que `a` — la vérification passait par accident.
  Chaque fichier est maintenant contrôlé individuellement (tests compris).
- Tests : la copie jetable du clone contient `install.sh` et `tests/`, ce que `make verify` lit.

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
