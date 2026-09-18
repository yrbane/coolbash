# Changelog

## 0.8.1 — 2026-09-18 · « Ménage dans les modules »
### Corrigé
- `please` : `alias please='sudo !!'` ne pouvait pas marcher (pas d'expansion d'historique dans un
  alias). C'est une fonction qui relit la commande précédente dans l'historique (`fc`) et l'affiche avant
  de la relancer avec `sudo`.
- `PATH` : le dossier des gems Ruby était figé sur `3.4.0` et ajouté même absent ; il est détecté
  par glob, quelle que soit la version, seulement s'il existe.
- `31-git` n'écrit plus `core.pager` dans `~/.gitconfig` à chaque ouverture de shell (deux
  processus git en moins au démarrage). `coolbash doctor` suggère la commande si `delta` est là.
- MOTD : `fastfetch` d'abord, `neofetch` (abandonné, absent de Debian 13) en repli ; `doctor` suit.
- `workon` : une activation en échec n'affiche plus « No .venv found ».
- `up` : la variable de boucle `i` ne fuit plus dans le shell.
- `timer` : mesure en millisecondes (`EPOCHREALTIME`) et renvoie le code retour de la commande.

## 0.8.0 — 2026-09-18 · « La police des icônes s'installe toute seule »
### Ajouté
- `cli/coolbash-font` : détecte une Nerd Font (`fc-list`) et installe JetBrainsMono Nerd Font dans
  `~/.local/share/fonts/coolbash-nerd`, sans `sudo` (curl ou wget, tar, xz). Seuls les styles
  Regular/Bold/Italic/BoldItalic sont gardés : ≈ 20 Mo au lieu de 233 Mo pour l'archive complète.
- `coolbash install` (`make install`) l'appelle quand aucune Nerd Font n'est présente. Un échec
  (pas de réseau, pas de `xz`…) n'interrompt **jamais** l'installation : le message indique le
  repli `COOLBASH_PROMPT_ICONS=basic`. Rien n'est installé pour root ni avec `COOLBASH_FONT=0`.
- `coolbash font` : relance l'installation de la police seule.
- `coolbash doctor` : ligne « police » — installée, absente (avec la commande qui répare et le
  repli sans police) ou indéterminée sans `fc-list`. En session SSH, rappelle que la police doit
  être sur la machine qui affiche le terminal.
- `COOLBASH_FONT_URL` : archive `.tar.xz` alternative (miroir interne).
### Modifié
- `make verify` et `test_syntax` couvrent `cli/coolbash-font` ; `tests/lib.sh` exporte
  `COOLBASH_FONT=0` : aucun test ne touche au réseau. `tests/test_font.sh` utilise une archive
  locale et un faux `fc-list`.

## 0.7.0 — 2026-09-08 · « Prompt contextuel »
### Ajouté
- **Chemin tronqué** : `PROMPT_DIRTRIM=3` par défaut (respecté s'il est déjà défini).
- **Chevron rouge** après une commande en échec, couleur utilisateur sinon.
- **Signaux en clair** dans le code retour : `130` → `INT`, `137` → `KILL`, `143` → `TERM`, `129`
  `HUP`, `131` `QUIT`, `134` `ABRT`, `139` `SEGV`, `141` `PIPE` ; les autres codes restent numériques.
- **Jobs en arrière-plan** : segment `⚙ N` quand `jobs -p` n'est pas vide.
- **Dossier non inscriptible** : cadenas devant le chemin.
- **Stash git** : `≡N` via `--show-stash`, toujours un seul appel `git status`.
- **Hôte contextuel** : icône prise en SSH (`SSH_CONNECTION`/`SSH_TTY`/`SSH_CLIENT`), cube dans un
  conteneur (`/.dockerenv`, `/run/.containerenv`, surchargeable par
  `COOLBASH_PROMPT_CONTAINER_MARKERS`). En SSH ou conteneur, couleur d'hôte dérivée du nom de la
  machine (palette TrueColor de 8, sinon 6 couleurs de base), stable d'une session à l'autre.
- **OSC 7** : le prompt annonce le dossier courant (`file://hôte/chemin`, encodé octet par octet)
  aux terminaux qui savent ouvrir un onglet au même endroit. `COOLBASH_PS1_OSC7=0`.
- **Notification de fin** : après une commande de plus de `COOLBASH_PROMPT_BELL_MS` (défaut
  30 000 ms, `0` = jamais), sonnerie + OSC 777 (`notify`) avec la commande et sa durée.
- **Versions php / node** : `composer.json` → `php 8.5`, `package.json` → `node 22.1`
  (majeure.mineure, icônes Nerd Font). Un seul lancement par binaire et par session, clé = chemin
  résolu (nvm est suivi). `COOLBASH_PROMPT_TOOLS=0` ; désactivé en mode `safe`.
- **Conda** : `CONDA_DEFAULT_ENV` dans le segment venv.
- Icônes `basic` correspondantes : `⚙ ⊘ ⇄ ▣`.
### Modifié
- Les fonctions qui gardent un état (`_coolbash_prompt_tools`) écrivent dans une variable passée en
  argument plutôt que sur stdout : une substitution `$(…)` perdait le cache à chaque prompt.
- Hachage du nom d'hôte sans sous-shell (`printf -v`). Chargement mesuré : ≈ 20 ms, construction
  du prompt ≈ 10 ms.
- Tests : 40 assertions de plus (sections 8 à 11) ; `with_prompt` neutralise `COLORTERM` pour des
  couleurs prévisibles ; faux `php`/`node` dans un `PATH` jetable pour vérifier le cache.

## 0.6.1 — 2026-09-07 · « Horloge, code retour, écran espacé »
- Icône devant l'heure (`nf-fa-clock_o`, `⏱` en `basic`) ; les crochets autour de l'heure ne
  restent que sans icône (`COOLBASH_PROMPT_ICONS=0`).
- Icône devant le code retour (`nf-fa-times_circle`) ; `✖` reste le repli en `basic` et `0`.
- Deux espaces entre l'icône écran et le nom de la machine : le glyphe `nf-fa-desktop` déborde
  de sa cellule et touchait le nom.
- Tests : clés `clock`/`err` définies, code retour avec et sans icône, heure avec ou sans crochets.

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
