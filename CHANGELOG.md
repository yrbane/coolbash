# Changelog

## 0.15.2 — 2026-09-29 · « La racine, même en overlay »
### Corrigé
- La ligne `Disk (/)` disparaissait quand `/` n'est pas un `/dev/…` (overlay d'un conteneur, CI
  Debian). La racine est toujours affichée ; le filtre « vrai périphérique, ≥ 80 % » ne s'applique
  qu'aux autres partitions. Le faux `df` des tests monte `/` en overlay. La 0.15.1 n'a pas été taguée.

## 0.15.1 — 2026-09-29 · « shellcheck de la CI »
### Corrigé
- `make verify` échouait sur la CI (shellcheck 0.9/0.10, SC2120 sur `_coolbash_motd_reboot`, dont
  les arguments ne servent qu'aux tests). Avertissement désactivé et commenté. La 0.15.0 n'a pas été
  taguée.

## 0.15.0 — 2026-09-29 · « Le MOTD dit l'état de la machine »
### Ajouté
- **`Mem:`** utilisée / totale (pourcentage), depuis `/proc/meminfo` (MemAvailable). Jaune ≥ 80 %,
  rouge ≥ 90 %.
- **`Load:`** les trois charges de `/proc/loadavg` et le nombre de cœurs (glob `/sys`). Jaune quand
  la charge 1 min atteint la moitié des cœurs, rouge quand elle les dépasse.
- **`Battery:`** depuis `/sys/class/power_supply/BAT*`, avec l'état. En décharge : jaune < 40 %,
  rouge < 20 %. Absente sans batterie.
- **`Reboot required`** : sur Arch, quand le dossier des modules du noyau qui tourne a disparu (le
  noyau a été mis à jour) ; sur Debian, quand `/var/run/reboot-required` existe. Rien en conteneur.
- **`Failed units:`** nombre et noms des unités systemd en échec, par un seul `systemctl --failed`
  (≈ 5 ms), seulement si > 0.
- **Note personnelle** : `~/.coolbash/motd.txt` affiché en cyan sous le bloc.
- **Disques** : `df -Phl` pour toutes les partitions locales, `/` toujours, les autres à partir de
  80 %. tmpfs, devtmpfs et loop (snap) ignorés.
- **`COOLBASH_MOTD_HIDE`** : `"battery load"` tait les lignes citées (mots : `date disk mem load
  battery reboot failed note`). Listée par `coolbash config`.
- Tests : chaque ligne (sans processus avec `PATH=/nonexistent`, faux `df` et `systemctl`, dossier
  de modules factice pour le reboot, note, masquage).

## 0.14.0 — 2026-09-29 · « Date et disque dans le MOTD »
### Ajouté
- **`Date:`** dans le bloc d'infos système, par le `printf %T` intégré à bash (aucun processus) :
  `Date: 2026-09-29 00:40 (mardi)`, jour de la semaine dans la langue du shell.
- **`Disk (/):`** utilisé / taille (pourcentage), par un seul `df -Ph /`. Pourcentage en jaune
  à partir de 80 %, en rouge à partir de 90 %. Sans `df`, la ligne est simplement absente.
- Tests : date du jour présente, ligne disque au bon format, et rien de cassé sans `df`.

## 0.13.2 — 2026-09-29 · « Chaque thème à égalité »
### Ajouté
- Test : chaque thème a la même probabilité de sortir, quelle que soit sa taille (un thème d'une
  ligne contre un de mille lignes, 400 tirages). C'était déjà le comportement : le tirage choisit
  d'abord un fichier à poids égal, puis une ligne dedans. Mesuré : Chuck sort 106 fois sur 1 200,
  soit un douzième.

## 0.13.1 — 2026-09-29 · « Trois fois plus de citations »
### Modifié
- **770 citations de plus** : chacun des onze thèmes rédigés passe d'une trentaine à une
  centaine de lignes (de 102 pour `unix` à 111 pour `cinema`). Originales pour l'essentiel ;
  domaine public attribué pour `moralistes`, `humour-noir`, `sciences`, `absurde` (Alphonse
  Allais) ; proverbes attestés de 26 origines ; répliques VF de 60 films et séries, dont 23
  francophones.
- Fusion avec dédoublonnage (accents et casse ignorés) et guillemets rééquilibrés.

## 0.13.0 — 2026-09-29 · « Une fortune en français »
### Ajouté
- **Citations françaises embarquées** dans `share/fortunes/<thème>.txt`, une par ligne, douze
  thèmes : `dev`, `unix`, `sysadmin`, `lois`, `corporate`, `absurde`, `humour-noir`, `moralistes`
  (auteurs du domaine public), `proverbes`, `sciences`, `cinema` et `chuck` (plus de 10 000
  Chuck Norris facts en français, collectés sur chucknorrisfacts.fr, dédoublonnés).
- **Tirage en pur bash** (`mapfile` + `RANDOM`) : zéro processus, là où le programme `fortune`
  coûtait 28 ms à chaque shell. Le programme `fortune` reste un repli quand aucun fichier n'existe.
- **`COOLBASH_FORTUNE="dev chuck"`** : thèmes retenus, chacun de même poids (un thème répété pèse
  plus lourd). Un thème inconnu est ignoré ; aucun thème valide = tous. Listée par `coolbash config`.
- **Thèmes personnels** : `~/.coolbash/fortunes/<thème>.txt`, jamais écrasés par `make install`.
- **`coolbash fortune [thème…]`** affiche une citation hors MOTD.
- `coolbash doctor` compte les thèmes de citations (requis) et ne liste plus `fortune`.
- Sans `cowsay`, la citation s'affiche quand même, sans vache.
- `make install` copie `share/fortunes/` ; les tests vérifient chaque thème (≥ 25 citations, pas
  de ligne vide ni d'espace final), le tirage sans aucun processus (`PATH=/nonexistent`), le
  filtre par thème, les thèmes personnels et la commande.

## 0.12.1 — 2026-09-28 · « La vache retrouve sa langue »
### Corrigé
- **MOTD** : `cowsay -e @@ -T U` au lieu de `-T U -p`. Même vache paranoïaque sous le cowsay
  Perl (28 ms) et sous Neo-cowsay (Go, 3 ms, binaire GitHub de Code-Hex), qui ignorait la
  langue quand `-p` était passé.
- Test : le module ne passe plus `-p` à cowsay.

## 0.12.0 — 2026-09-28 · « Le MOTD ne fait plus attendre »
### Corrigé
- **Démarrage de 2,7 s** sur un poste Arch : `⚡ démarrage 2720 ms · CoolBash 2687 ms`, dont
  `70-motd` pour presque tout. `neofetch` calculait GPU, résolution, thème, police du
  terminal… pour qu'on n'en garde que 6 lignes (`neofetch --stdout | sed -n 1,6p`) :
  de 0,5 à 2,7 s par shell selon le cache.
### Modifié
- **Infos système en pur bash** : titre `user@host`, OS (`/etc/os-release`), Host
  (`/sys/class/dmi/id/product_name`), Kernel (`/proc/sys/kernel/osrelease`) et Uptime
  (`/proc/uptime`, format neofetch `1 day, 7 hours, 1 min`). Même présentation, zéro
  processus, ≈ 1 ms. Sans `/proc` (macOS), le bloc est simplement absent.
- `fastfetch` et `neofetch` ne sont plus utilisés ni suggérés par `coolbash doctor`.
- Tests : le bloc s'affiche avec `PATH=/nonexistent`, le module ne cite plus
  neofetch/fastfetch hors commentaires.

## 0.11.0 — 2026-09-28 · « Combien de temps pour ouvrir un shell ? »
### Ajouté
- **Temps de démarrage affiché** à l'ouverture de chaque shell interactif, sous le MOTD :
  `⚡ démarrage 412 ms · CoolBash 39 ms`. Le total est l'âge réel du processus bash
  (`/proc`, Linux), donc `/etc/bash.bashrc`, `~/.profile` et tout le `~/.bashrc` compris ;
  la part CoolBash est mesurée avec `EPOCHREALTIME`. Vert sous 250 ms, jaune sous 700 ms,
  rouge au-delà.
- **Le chiffre dit où chercher** : quand CoolBash pèse moins de la moitié d'un démarrage lent,
  la ligne renvoie vers `/etc/bash.bashrc`, `~/.profile` et le reste du `~/.bashrc` ;
  sinon elle propose `COOLBASH_STARTUP_TIME=verbose`, qui affiche le temps de **chaque module**.
- **`COOLBASH_STARTUP_TIME`** : `1` (défaut), `0` = muet, `verbose` = détail par module.
  Listée par `coolbash config`.
- Un second `source ~/.bashrc` dans un shell déjà ouvert n'affiche que la part CoolBash :
  l'âge du processus n'aurait alors plus de sens.
- Tests : `tests/test_startup.sh` (affichage, shell non interactif muet, `0`, `verbose`,
  re-source, total incluant ce qui précède la ligne `source`) ; `assert_not_contains` dans `lib.sh`.

## 0.10.0 — 2026-09-19 · « Un ~/.bashrc d'une ligne »
### Ajouté
- **Module `35-toolchains`** : remplace les blocs que les installeurs ajoutent au `~/.bashrc`.
  `~/.cargo/bin`, pnpm (`PNPM_HOME`), Android SDK (`ANDROID_HOME`, `platform-tools`, `emulator`),
  `~/.foundry/bin` — chacun seulement si le dossier existe, sans doublon, sans aucun processus.
  Les variables déjà définies sont respectées. Rien en mode `safe`.
- **nvm paresseux** : sourcer `nvm.sh` coûtait ≈ 700 ms à chaque shell (mesuré), contre ≈ 25 ms
  pour tout CoolBash. Le node par défaut est mis dans le `PATH` en lisant `~/.nvm/alias/default`
  (alias exact `24.14.0`, partiel `24`, ou symbolique `lts/*` → version installée la plus
  récente) : `node`, `npm`, `npx`, les binaires globaux et le segment node du prompt marchent
  tout de suite. La fonction `nvm` charge le vrai `nvm.sh` (et sa completion) à son premier
  appel. `COOLBASH_NVM_LAZY=0` rétablit le chargement immédiat.
- README : section « Vider son `~/.bashrc` ».
### Modifié
- `tests/lib.sh` neutralise `NVM_DIR`, `PNPM_HOME`, `ANDROID_HOME` hérités du shell appelant.

## 0.9.5 — 2026-09-18 · « update ne scie plus la branche sur laquelle il est assis »
- **Erreur de syntaxe à la fin d'un `coolbash update` réussi** (« près du symbole inattendu ;; ») :
  `update` est exécuté par `~/.coolbash/cli/coolbash`, que `make install` réécrivait en place
  pendant que bash le lisait ; bash reprenait au même décalage dans le nouveau contenu. Les
  fichiers sont maintenant installés par copie puis `mv` (nouvel inode) : le script en cours
  garde l'ancien jusqu'au bout. La mise à jour elle-même n'était pas compromise.
- Test : une CLI installée qui se réinstalle pendant son exécution ne produit aucune erreur.

## 0.9.4 — 2026-09-18 · « source ~/.bashrc après une mise à jour »
- **Erreur de syntaxe au rechargement** : après la mise à jour depuis une version où `please` était
  un alias, `source ~/.bashrc` dans le shell déjà ouvert développait cet alias à la lecture de
  `please() {` (« erreur de syntaxe près du symbole inattendu ( ») et le module `30-aliases` ne se
  chargeait pas. Chaque module retire maintenant (`unalias`) un éventuel alias homonyme avant de
  définir ses fonctions publiques — vaut aussi pour un `~/.bash_aliases` qui en redéfinirait une.
  Un nouveau terminal n'était pas touché.

## 0.9.3 — 2026-09-18 · « Les tests ne touchent plus au vrai HOME »
### Corrigé
- **La suite de tests supprimait la police de l'utilisateur.** Depuis la 0.9.0, `make uninstall`
  retire `~/.local/share/fonts/coolbash-nerd` ; or `tests/test_make.sh` lançait `make uninstall`
  avec le vrai `HOME`. Chaque `make test` — donc chaque `coolbash update` — effaçait la police
  installée. `tests/lib.sh` impose désormais un `HOME` jetable à **tous** les tests (et retire
  `XDG_*_HOME`) ; un garde-fou le vérifie dans `test_make`. Après mise à jour : `coolbash font`.
- **`coolbash update` échouait depuis un vrai terminal** : bash pose `COLUMNS` et `LINES`
  (`checkwinsize`) dès qu'un terminal est attaché, et les tests d'isolation les prenaient pour
  des fuites de la CLI et du prompt. Ajoutées au bruit connu de bash.

## 0.9.2 — 2026-09-18 · « update fonctionne aussi en SSH »
- **`coolbash update` refusait d'installer depuis une session SSH** : lancée en SSH (ou dans un
  conteneur), la suite voyait le prompt passer à l'icône prise/cube — comportement voulu — et
  deux assertions « en local » échouaient, donc rien n'était installé. `tests/lib.sh` neutralise
  `SSH_*` et les marqueurs de conteneur ; les tests qui veulent ces contextes les posent eux-mêmes.
  Trouvé grâce au job CI Debian 13 (conteneur Docker), reproduit avec `SSH_CONNECTION=x make test`.
- Les 0.9.0 et 0.9.1 n'ayant pas été taguées (CI rouge sur ce job), cette release couvre leurs notes.

## 0.9.1 — 2026-09-18 · « Tests verts sans locale UTF-8 »
- Le nouveau job CI Debian 13 a révélé que la suite échouait sans locale UTF-8 (conteneur nu,
  `su -c`) : bash laissait les `$'\uXXXX'` des scripts de test tels quels, 16 assertions d'icônes
  tombaient alors que le module produisait les bons glyphes. `tests/lib.sh` bascule sur `C.UTF-8`
  quand la locale courante n'est pas UTF-8. Aucun changement dans les modules.
- La 0.9.0 n'ayant pas été taguée (CI rouge sur ce job), cette release couvre aussi ses notes.

## 0.9.0 — 2026-09-18 · « Moins de surprises »
### Ajouté
- **Repli automatique des icônes** : `make install` note dans `<prefix>/.nerdfont` si une Nerd Font
  est présente ; sans police, le prompt passe en `basic` au lieu d'afficher des carrés. Ignoré en
  SSH (la police qui compte est celle du poste qui affiche) et dès que `COOLBASH_PROMPT_ICONS`
  est défini.
- **`coolbash config`** : tous les réglages `COOLBASH_*`, valeur effective, « défini » ou
  « défaut », rôle. Exécutée dans le shell courant pour voir les variables non exportées. Un test
  vérifie que chaque variable documentée dans le README y figure.
- **`coolbash update` dit ce qu'il a fait** : `0.8.1 → 0.9.0`, « déjà à jour (x) », ou un échec
  explicite (« Tests en échec : rien n'a été installé, version en place : x »).
- **`coolbash uninstall`** retire aussi la police installée par CoolBash (`coolbash-font remove`).
- **fzf** : `Ctrl-R`, `Ctrl-T`, `Alt-C` chargés en shell interactif quand fzf est là (Arch, Debian,
  Fedora, `~/.fzf`). `COOLBASH_FZF=0`, `COOLBASH_FZF_KEYBINDINGS`. Jamais en mode `safe`.
- **Alias pacman** : `au`, `aug`, `asr`, `ain`, `arm`, `apc` routés vers pacman quand apt est absent
  (`au` fait `-Syu`, jamais `-Sy` seul).
- **`extract -d`** : extrait dans un dossier au nom de l'archive. `extract` vérifie que l'outil
  (`unrar`, `7z`, `unzip`…) existe et renvoie 3 avec son nom sinon.
- `HISTIGNORE` écarte aussi `history*`, `fg`, `bg`, `jobs`.
- **CI Debian 13** : second job dans un conteneur `debian:13`, sous un utilisateur non root.
### Modifié
- `install.sh` relancé sur un clone existant le met à jour (`git pull --rebase`) au lieu d'échouer ;
  il refuse un `~/.coolbash` qui n'est pas un clone git, sans y toucher. `COOLBASH_REPO_URL`.
- shellcheck passe de `-S error` à `-S warning` sur les modules : `command ls` dans le test de
  `--group-directories-first`, `mkcd` gère l'échec de `cd`, `GPG_TTY` déclaré puis exporté ; les
  faux positifs des namerefs sont désactivés par fichier, avec leur raison.

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
