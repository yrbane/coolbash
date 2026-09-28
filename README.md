# 🧊 CoolBash

[![CI](https://github.com/yrbane/coolbash/actions/workflows/ci.yml/badge.svg)](https://github.com/yrbane/coolbash/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-0.21.0-blue.svg)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> **Make your Bash cool again.**  
> Modern, modular, and maintainable Bash configuration — the *cool* way 😎

---

## 🚀 Quick Install

Installe CoolBash en une seule commande (dépôt public requis pour l'URL brute) :

```bash
curl -fsSL https://raw.githubusercontent.com/yrbane/coolbash/main/install.sh | bash
````

Ou clone le dépôt manuellement :

```bash
git clone https://github.com/yrbane/coolbash.git
cd coolbash
make install
```

Recharge ensuite ton shell :

```bash
source ~/.bashrc
```

---

## 🧩 Features

✨ **Modular design** — chaque domaine (historique, prompt, couleurs, etc.) a son module dédié.
🧠 **Documenté** — commentaires détaillés en français, code en anglais.
🎨 **Prompt stylé** — couleurs adaptatives, icônes Nerd Font, emoji différents pour root et user.
⚡ **Performant** — historique partagé sans rechargement complet, prompt léger, et le temps de démarrage affiché à chaque ouverture (`⚡ démarrage 412 ms · CoolBash 39 ms`).
🔐 **Safe by default** — `umask`, `noclobber`, et alias protecteurs (`rm -i`, `cp -i`, `mv -i`).
🐧 **Compatible serveurs** — fonctionne sans dépendances inutiles.

---

## 🧰 CLI Commands

CoolBash vient avec sa propre interface CLI :

```bash
coolbash <command>
```

| Commande    | Description                                   |
| ----------- | --------------------------------------------- |
| `install`   | Installe CoolBash dans `~/.coolbash`, et la Nerd Font des icônes si aucune n'est présente |
| `update`    | `git pull`, puis tests, puis install (clone git requis) ; annonce `0.8.1 → 0.9.0`, « déjà à jour », ou l'échec |
| `font`      | Installe (ou réessaie d'installer) la Nerd Font des icônes du prompt |
| `verify`    | Vérifie la syntaxe (+ shellcheck si présent)  |
| `test`      | Lance la suite de tests                       |
| `uninstall` | Supprime complètement CoolBash, y compris la police qu'il a installée |
| `init`      | Charge tous les modules dans le shell courant |
| `version`   | Affiche la version                            |
| `config`    | Tous les réglages `COOLBASH_*` avec leur valeur effective (définie ou par défaut) |
| `fortune`   | Une citation du MOTD, au hasard ou d'un thème donné : `coolbash fortune chuck` ; `fortune --add "texte" [thème]` en ajoute une à `~/.coolbash/fortunes/` |
| `theme`     | `theme` liste les palettes du prompt avec un aperçu ; `theme nord` l'enregistre (`~/.coolbash/theme`) et l'applique au shell courant |
| `sync`      | `sync [--update] [--overrides] user@host…` : pousse `fortunes/`, `motd.txt` et `theme` vers `~/.coolbash` d'autres machines par rsync sur SSH ; `--overrides` ajoute `90-local-overrides`, `--update` y lance `coolbash update` |
| `bench`     | `bench [N]` : N ouvertures de shell interactif (20 par défaut), moyenne, min, max, puis le coût de chaque module |
| `doctor`    | Diagnostic : bash, `.bashrc`, modules, citations, locale, outils optionnels, Nerd Font, et ce que ton `~/.bashrc` refait à la main (nvm, cargo, PATH, alias…) alors qu'un module s'en charge |
| `help`      | Affiche l’aide de la CLI                      |

La fonction shell `coolbash` est disponible dès que `~/.bashrc` a chargé CoolBash.
Les commandes `install`/`update`/`verify`/`test`/`uninstall` délèguent au `Makefile` du clone git,
retrouvé via `COOLBASH_REPO`, le fichier `~/.coolbash/.repo` écrit à l'installation, ou le parent du script.

---

## 🗂️ Project Structure

```
coolbash/
├─ cli/
│   ├─ coolbash               # CLI principale
│   └─ coolbash-font          # détection / installation de la Nerd Font
├─ modules/
│   ├─ 00-core.bash
│   ├─ 10-history.bash
│   ├─ 20-path-and-colors.bash
│   ├─ 30-aliases.bash
│   ├─ 31-git.bash
│   ├─ 32-network.bash
│   ├─ 33-devtools.bash
│   ├─ 34-python-venv.bash
│   ├─ 35-toolchains.bash
│   ├─ 40-functions.bash
│   ├─ 41-navigation.bash
│   ├─ 50-prompt.bash
│   ├─ 60-completion.bash
│   ├─ 70-motd.bash
│   └─ 90-local-overrides.bash  # jamais écrasé par make install
├─ tests/
│   ├─ run.sh                 # lanceur (bash pur, zéro dépendance)
│   ├─ lib.sh                 # assertions
│   └─ test_*.sh
├─ .github/workflows/ci.yml
├─ Makefile
├─ install.sh
├─ CHANGELOG.md
├─ README.md
└─ LICENSE
```

---

## 🧩 Modules Overview

| Module                    | Rôle principal                                      |
| ------------------------- | --------------------------------------------------- |
| `00-core.bash`            | Variables d’environnement, sécurité de base         |
| `10-history.bash`         | Historique horodaté partagé entre sessions, `Ctrl-R` fzf |
| `20-path-and-colors.bash` | PATH propre, couleurs auto                          |
| `30-aliases.bash`         | Alias utiles et sûrs, paquets `apt` ou `pacman`     |
| `31-git.bash`             | Raccourcis Git, `gwip`/`gunwip`, `gfix`, `gsw`, `gopen`, garde-fou du `push --force` sur main |
| `32-network.bash`         | Commandes réseau et IP                              |
| `33-devtools.bash`        | Symfony, PHP, yt-dlp                                |
| `34-python-venv.bash`     | Helpers pour venv Python                            |
| `35-toolchains.bash`      | SDK du HOME dans le `PATH` (cargo, pnpm, Android, foundry), nvm paresseux |
| `40-functions.bash`       | Fonctions utilitaires (`mkcd`, `extract`, `timer`, `backup`, `whoport`, `serve`, `cheat`…) |
| `41-navigation.bash`      | `j` (saut de dossier par fréquence, pur bash), `bd`, `h`, `hstats`, paquet suggéré pour une commande introuvable |
| `50-prompt.bash`          | Prompt dynamique (git, venv, durée, emoji, icônes)  |
| `60-completion.bash`      | Completions Bash/Git/fzf                            |
| `70-motd.bash`            | État de la machine (voir ci-dessous), puis une citation française (12 thèmes, `share/fortunes/`) dans la bouche de cowsay, juste au-dessus du prompt ; une fois par session |
| `90-local-overrides.bash` | Surcharges locales (vide par défaut)                |

---

## 🖥️ Example Prompt

```bash
🐧  14:32:10  seb at   laptop   main*+?↑1≡1   .venv   8.5   22.1   1.23s   1   INT
 …/projects/coolbash $
```

🔹 Emoji aléatoire par session (aucun en mode `safe`)
🔹 Icônes **Nerd Font** devant chaque segment (heure, utilisateur, host, branche, venv, php/node,
   durée, jobs, code retour, dossier, cadenas pour root ou dossier en lecture seule) : il faut une [Nerd Font](https://www.nerdfonts.com/) dans le terminal.
   `COOLBASH_PROMPT_ICONS=basic` bascule sur des symboles Unicode standard (`⎇ ⚗ ⧗ ⚠`),
   `COOLBASH_PROMPT_ICONS=0` les retire. Par défaut : `basic` en mode `safe`, `0` sur la console
   (`TERM=linux`), `nerd` sinon
🔹 **Icônes illisibles (carrés, `?`) ?** Il manque la police. `coolbash install` installe
   JetBrainsMono Nerd Font dans `~/.local/share/fonts/coolbash-nerd` (≈ 20 Mo, sans `sudo`) quand
   aucune Nerd Font n'est détectée ; `coolbash font` relance l'installation, `coolbash doctor` dit
   si elle manque. Sans Nerd Font détectée à l'installation, le prompt passe tout seul aux icônes
   `basic` (sauf en SSH, où la détection côté serveur ne veut rien dire). Reste une étape manuelle : **choisir la police dans le profil du terminal**.
   En SSH, c'est la machine qui affiche le terminal qui doit avoir la police, pas le serveur
🔹 Couleurs dynamiques (TrueColor si supporté)
🔹 Segments : utilisateur, host, git, venv/conda, php/node, durée, jobs, code retour
🔹 Hôte selon le contexte : écran en local, prise en SSH avec une **couleur dérivée du nom de la
   machine** (stable d'une session à l'autre, chaque serveur a la sienne), cube dans un conteneur
🔹 Git en **un seul appel** sans verrou : `*` indexé, `+` modifié, `?` non suivi, `!` conflit,
   `↑N`/`↓N` avance/retard sur l'upstream, `≡N` stash, sha court si HEAD détachée
🔹 Versions php et node (majeure.mineure) si `composer.json` / `package.json` est présent, un seul
   lancement par binaire et par session
🔹 Code retour en clair pour les signaux (`INT`, `KILL`, `TERM`…), chevron rouge après un échec,
   `⚙ N` jobs en arrière-plan, cadenas devant un dossier non inscriptible
🔹 `PROMPT_DIRTRIM=3` : le chemin ne garde que les trois derniers dossiers
🔹 Durée mesurée par `PS0` + `EPOCHREALTIME` (sans `trap DEBUG`), affichée à partir de 1 s
🔹 À l'Entrée, `PS0` affiche l'heure réelle de départ en gris (`  ⏱ 14:32:41`) et met la commande
   en cours dans le titre du terminal ; le prompt suivant remet `user@host: dossier`
🔹 OSC 7 : le terminal connaît le dossier courant, un nouvel onglet (foot, kitty, wezterm, VTE)
   s'ouvre au même endroit. Après une commande de plus de 30 s : sonnerie + notification OSC 777

---

## 🛠️ Development

Installer depuis le clone et recharger :

```bash
make install
source ~/.bashrc
```

### 🧪 Tests

Suite de tests en bash pur, sans dépendance (shellcheck est utilisé s'il est présent) :

```bash
make test               # ou : bash tests/run.sh [motif]
make lint               # bash -n + shellcheck + shfmt (style), = make verify
make fmt                # applique shfmt (options dans .editorconfig)
```

La CI épingle **shellcheck 0.11.0** et **shfmt 3.14.1** : les mêmes versions localement évitent
les avertissements propres à une version. Trois jobs : Ubuntu, Debian 13 sous un utilisateur
normal, et **installation à froid** (Debian nue, `install.sh`, premier shell : le MOTD, le temps
de démarrage et le prompt sont capturés et vérifiés).

| Fichier                       | Ce qui est vérifié                                                                 |
| ----------------------------- | ---------------------------------------------------------------------------------- |
| `tests/test_cli_isolation.sh` | La CLI sourcée ne laisse **rien** dans le shell hors `COOLBASH_*` / `coolbash*` ; le garde-fou de nvm (`PREFIX`) est rejoué |
| `tests/test_cli_commands.sh`  | `help`, `version` (cohérente avec le CHANGELOG), `doctor`, ordre de chargement, module en échec, `coolbash` hors clone |
| `tests/test_modules.sh`       | Chaque module se charge sans erreur ni sortie parasite et renvoie 0 ; locale ; historique écrit dès le prompt suivant ; completion différée |
| `tests/test_make.sh`          | `make install` / réinstall / `uninstall` / `update` dans un HOME jetable, sur une copie du clone |
| `tests/test_syntax.sh`        | `bash -n` sur tout + shellcheck                                                    |
| `tests/test_prompt.sh`        | Pas de trap DEBUG, durée réelle mesurée en shell interactif, formatage, segment git sur un dépôt jetable, isolation des noms du prompt, icônes (`nerd`/`basic`/`0`, résolution du mode), signaux, chevron, jobs, lecture seule, SSH/conteneur, OSC 7, notification, cache php/node, conda |
| `tests/test_font.sh`          | Détection de la Nerd Font, installation depuis une archive locale (zéro réseau), `make install` jamais bloqué par la police, `doctor` |
| `tests/test_isolation_modules.sh` | Chaque module n'expose que `COOLBASH_*`, des variables MAJUSCULES, `_coolbash_*` ou l'API publique documentée ici |
| `tests/test_mode_safe.sh`     | `COOLBASH_MODE=safe` (emoji, git, MOTD, completion) et `COOLBASH_DISABLE`          |
| `tests/test_perf.sh`          | Budget de démarrage : `init` complet ≤ 200 ms (`COOLBASH_TEST_INIT_BUDGET_MS`)     |

### ⚠️ Règle d'or de la CLI

`cli/coolbash` est **sourcé** par `~/.bashrc` : tout ce qu'il définit reste dans le shell de
l'utilisateur. Variables préfixées `COOLBASH_`, fonctions préfixées `coolbash` / `_coolbash_`,
jamais de `set -e`. Un `PREFIX=` générique a déjà cassé nvm (« nvm is not compatible with the
PREFIX environment variable ») — `tests/test_cli_isolation.sh` empêche la récidive.

Mettre à jour depuis le dépôt :

```bash
coolbash update
```

Désinstaller proprement :

```bash
coolbash uninstall
```

---

## ⚙️ Configuration

Variables lues au chargement (à placer avant la ligne `source` du `.bashrc`, ou dans l'environnement) :

| Variable                        | Effet                                                                 |
| ------------------------------- | --------------------------------------------------------------------- |
| `COOLBASH_MODE=safe`            | Shell minimal : pas d'emoji, ni git dans le prompt, ni MOTD, ni completion différée. Défaut pour root. |
| `COOLBASH_DISABLE="70-motd 33"` | Modules à ne pas charger (nom complet, numéro seul ou nom sans numéro) |
| `COOLBASH_PROMPT_MIN_MS`        | Durée minimale affichée dans le prompt (défaut `1000` ms)             |
| `COOLBASH_PROMPT_GIT=0`         | Désactive le segment git                                              |
| `COOLBASH_PROMPT_GIT_UNTRACKED=0` | Ignore les fichiers non suivis (gros dépôts)                        |
| `COOLBASH_PROMPT_EMOJI`         | Emoji de session imposé (vide = aucun)                                |
| `COOLBASH_PROMPT_ICONS`         | Icônes du prompt : `nerd` (Nerd Font, défaut), `basic` (Unicode standard, défaut en mode `safe`), `0` (aucune, défaut si `TERM=linux`) |
| `COOLBASH_NVM_LAZY=0`           | Charger `nvm.sh` au démarrage (≈ 0,7 s par shell) au lieu du chargement paresseux |
| `COOLBASH_GIT_GUARD=0`          | `git push --force` sur main/master sans confirmation                  |
| `COOLBASH_J=0`                  | Ne pas noter les `cd` (désactive `j`)                                  |
| `COOLBASH_CNF=0`                | Pas de suggestion de paquet pour une commande introuvable              |
| `COOLBASH_SERVE_PORT`           | Premier port essayé par `serve` (défaut `8000`)                        |
| `COOLBASH_MOTD_HIDE`            | Lignes du MOTD à taire, ex. `"battery load"` (mots : `date disk mem load battery reboot failed update note`) |
| `COOLBASH_FORTUNE`              | Thèmes de citations du MOTD, ex. `"dev chuck"` (défaut : tous, un thème répété pèse plus lourd) |
| `COOLBASH_STARTUP_TIME`         | Temps de démarrage affiché à l'ouverture : `1` (défaut), `0` = muet, `verbose` = temps de chaque module. Le total est l'âge du processus (tout le `~/.bashrc` compris), la part CoolBash à côté |
| `COOLBASH_FZF=0`                | Pas de raccourcis fzf (`Ctrl-R`, `Ctrl-T`, `Alt-C`), chargés sinon en shell interactif |
| `COOLBASH_FZF_KEYBINDINGS`      | Fichier `key-bindings.bash` à utiliser (sinon emplacements Arch, Debian, Fedora, `~/.fzf`) |
| `COOLBASH_FONT=0`               | `install` n'installe pas de police (serveurs, machines sans réseau)   |
| `COOLBASH_FONT_URL`             | Archive `.tar.xz` de la police (miroir interne)                       |
| `COOLBASH_PROMPT_TOOLS=0`       | Pas de versions php/node dans le prompt (désactivé en mode `safe`)     |
| `COOLBASH_PROMPT_BELL_MS`       | Sonnerie + notification après une commande de plus de N ms (défaut `30000`, `0` = jamais) |
| `COOLBASH_PROMPT_THEME`         | Palette du prompt : `coolbash` (défaut), `nord`, `dracula`, `solarized`, `gruvbox`, `mono` ; sinon le fichier `~/.coolbash/theme` écrit par `coolbash theme` |
| `COOLBASH_UPDATE_CHECK=0`       | Ne jamais vérifier les mises à jour (sinon un `git fetch` par jour, en arrière-plan, et le MOTD annonce `⇡ CoolBash x.y.z disponible`) |
| `COOLBASH_PROMPT_PATH_FISH=0`   | Jamais de chemin abrégé façon fish (`~/D/coolbash/modules`), même quand il dépasse la moitié du terminal |
| `COOLBASH_PROMPT_TRANSIENT=1`   | Expérimental : après l'Entrée, le prompt de deux lignes est remplacé par `chemin $ commande` sur une ligne |
| `COOLBASH_PS1_OSC7=0`           | Ne pas annoncer le dossier courant au terminal (OSC 7)                 |
| `COOLBASH_PROMPT_CONTAINER_MARKERS` | Fichiers révélant un conteneur (défaut `/.dockerenv /run/.containerenv`) |
| `PROMPT_DIRTRIM`                | Dossiers gardés dans `\w` (défaut `3`, réglage bash natif)             |
| `COOLBASH_PS0_STAMP=0`          | Pas d'heure de départ en gris sous la commande                        |
| `COOLBASH_PS0_TITLE=0`          | Ne pas mettre la commande en cours dans le titre du terminal          |
| `COOLBASH_PS0_EXTRA`            | Fragment ajouté à la fin de `PS0` (PS0 personnel)                     |
| `COOLBASH_MOTD=0` / `MOTD_DISABLE=1` | Pas de MOTD                                                      |

### 🖥️ État de la machine dans le MOTD

D'abord un bloc à la neofetch, mais lu dans `/proc`, `/sys` et quelques fichiers :
aucun processus, sauf un `df -Phl` et un `systemctl --failed` (≈ 5 ms chacun). Une ligne
n'apparaît que si elle a quelque chose à dire.

| Ligne            | Source                                   | Couleur                              |
| ---------------- | ---------------------------------------- | ------------------------------------ |
| `user@host`, OS, Host, Kernel, Uptime | `/etc/os-release`, `/sys/class/dmi`, `/proc` | —                  |
| `Date:`          | `printf %T` de bash                      | —                                    |
| `Disk (/):`      | `df -Phl` : `/` toujours, les autres partitions à partir de 80 % (jamais tmpfs ni loop) | jaune ≥ 80 %, rouge ≥ 90 % |
| `Mem:`           | `/proc/meminfo` (MemAvailable)           | jaune ≥ 80 %, rouge ≥ 90 %           |
| `Load:`          | `/proc/loadavg` + nombre de cœurs        | jaune ≥ cœurs/2, rouge ≥ cœurs       |
| `Battery:`       | `/sys/class/power_supply/BAT*`           | en décharge : jaune < 40 %, rouge < 20 % |
| `Reboot required` | modules du noyau courant disparus (Arch) ou `/var/run/reboot-required` (Debian) | rouge |
| `Failed units:`  | `systemctl --failed`, seulement si > 0   | rouge                                |
| `⇡ CoolBash x.y.z disponible` | `.update-available`, écrit par la vérification quotidienne | jaune          |
| note             | `~/.coolbash/motd.txt`, ton pense-bête   | cyan                                 |

`COOLBASH_MOTD_HIDE="battery load"` tait les lignes citées.

### 💬 Citations du MOTD

Le MOTD tire une citation **en français** dans `share/fortunes/<thème>.txt` (une par ligne), en pur
bash : zéro processus, là où le programme `fortune` coûtait 28 ms. Douze thèmes sont embarqués, une centaine de citations chacun (et dix mille pour Chuck) :

| Thème         | Contenu                                                    |
| ------------- | ---------------------------------------------------------- |
| `dev`         | Le métier : estimations, TODO, « ça marche sur ma machine » |
| `unix`        | Shell, pipes, `rm -rf`, l'homme qui a lu le man             |
| `sysadmin`    | Prod, sauvegardes, DNS, « le vendredi on ne déploie pas »   |
| `lois`        | Parkinson, Peter, Hofstadter, Brandolini, Conway…           |
| `corporate`   | Réunions qui auraient pu être un mail                       |
| `absurde`     | Logique qui mène à tout, à condition d'en sortir            |
| `humour-noir` | Cynisme et post-mortem                                      |
| `moralistes`  | La Rochefoucauld, La Bruyère, Chamfort, Montaigne, Pascal, Voltaire, Jules Renard |
| `proverbes`   | Français, chinois, africains, arabes, japonais              |
| `sciences`    | Poincaré, Pasteur, Feynman, Einstein, chat de Schrödinger   |
| `cinema`      | Répliques cultes en VF                                      |
| `chuck`       | Plus de 10 000 Chuck Norris facts en français               |

- `COOLBASH_FORTUNE="dev chuck"` limite le tirage à ces thèmes. Chaque fichier retenu a le même poids :
  `"chuck chuck dev"` favorise Chuck.
- Tes propres thèmes : un fichier `~/.coolbash/fortunes/<thème>.txt`, jamais touché par `make install`.
- `coolbash fortune [thème…]` en affiche une, hors MOTD. Sans aucun fichier, le programme `fortune` est utilisé s'il existe.

### 🧹 Vider son `~/.bashrc`

Les installeurs (pnpm, nvm, Android Studio, foundry, rustup…) ajoutent chacun leur bloc au
`~/.bashrc`. `35-toolchains` les remplace : emplacements standard, seulement s'ils existent, sans
doublon, **sans lancer de processus**. nvm est le cas qui compte : sourcer `nvm.sh` coûte ≈ 0,7 s
à chaque terminal ; ici le node de `~/.nvm/alias/default` est mis dans le `PATH` par simple
lecture de fichier, et `nvm` ne se charge qu'à son premier appel. Ce qui est propre à une machine
(SDK rangé ailleurs, alias, fonctions perso, `umask`) va dans `90-local-overrides.bash`. Le
`~/.bashrc` peut alors se réduire à la ligne `source`.

Fichiers utilisateur chargés s'ils existent : `~/.bash_aliases` (par `30-aliases`), `~/.dircolors`
(par `20-path-and-colors`), `~/.fzf.bash` (au premier Tab, par `60-completion`), et
`~/.coolbash/modules/90-local-overrides.bash`, jamais écrasé par `make install`.

## 🧩 API publique

Fonctions volontairement exposées dans le shell (tout le reste est préfixé `_coolbash_`) :

| Fonction                       | Module                | Rôle                                        |
| ------------------------------ | --------------------- | ------------------------------------------- |
| `path_prepend`, `path_append`  | `00-core`             | Ajout idempotent au `PATH`                  |
| `please`                       | `30-aliases`          | Relance la dernière commande avec `sudo` ; redirections, pipes et `&&` passent entiers sous `sudo bash -c` |
| `backup`                       | `40-functions`        | `backup fichier dossier…` : copie horodatée à côté, `nom.AAAA-MM-JJ-HHMM.bak` (`cp -a`) |
| `whoport`                      | `40-functions`        | `whoport 8080` : quel processus tient ce port (pid, nom, ligne de commande), via `ss` ou `lsof` |
| `serve`                        | `40-functions`        | `serve [dossier] [port]` : serveur HTTP statique (python3, sinon php) sur le premier port libre dès `COOLBASH_SERVE_PORT` (8000), URL affichée |
| `gwip`, `gunwip`               | `31-git`              | Commit « WIP » de tout l'état courant (hooks ignorés, `[skip ci]`), et son annulation (refusée si le dernier commit n'est pas un WIP) |
| `gfix`                         | `31-git`              | `gfix <commit>` : fixup de ce qui est indexé, puis rebase autosquash sans éditeur |
| `gsw`                          | `31-git`              | `gsw [motif]` : changer de branche — unique = direct (distante suivie), sinon fzf, sinon la liste |
| `gopen`                        | `31-git`              | `gopen [-p] [fichier[:ligne]]` : le dépôt ou le fichier sur la branche courante dans le navigateur (`-p` affiche l'URL) |
| `git`                          | `31-git`              | Garde-fou : `git push --force` sur main/master demande confirmation ; `--force-with-lease` (`gpf`) reste libre. `COOLBASH_GIT_GUARD=0` |
| `j`                            | `41-navigation`       | `j coolb` : saute dans le dossier connu le plus fréquent/récent qui correspond (les `cd` sont notés à chaque prompt dans `~/.coolbash/dirs`) ; `j` seul liste ; complétion par Tab |
| `bd`                           | `41-navigation`       | `bd Dev` : remonte jusqu'au dossier parent nommé (exact, sinon préfixe) |
| `h`, `hstats`                  | `41-navigation`       | `h motif` cherche dans l'historique daté ; `hstats [N]` tes commandes les plus fréquentes avec leur part |
| `command_not_found_handle`     | `41-navigation`       | Commande introuvable : le paquet qui la fournit (`pacman -F`, `apt-file`), sinon des noms proches. Shell interactif seulement |
| `cheat`                        | `40-functions`        | `cheat tar` : exemples par `tldr` si présent, sinon la section EXAMPLES du man, sinon `--help` |
| `man`                          | `40-functions`        | `man` colorisé                              |
| `mkcd`, `extract`, `up`, `timer` | `40-functions`      | Créer+entrer, extraire une archive (`extract -d` : dans un dossier à son nom), remonter de N répertoires, chronométrer |
| `coolbash_log`, `coolbash_error` | `40-functions`      | Messages colorés (ex-`log`/`error`, renommés en 0.4.0) |
| `mkvenv`, `workon`             | `34-python-venv`      | Créer/activer un venv Python                |
| `nvm`                          | `35-toolchains`       | Amorce : charge le vrai `nvm.sh` au premier appel (seulement si `~/.nvm` existe) |

Le test `tests/test_isolation_modules.sh` échoue si un module expose autre chose.

## 🧠 Philosophy

CoolBash respecte la simplicité et la lisibilité :

* Code en **anglais**
* Documentation en **français**
* Modules **indépendants et ordonnés**
* Compatibilité **serveur / dev local**
* **Zéro dépendance** obligatoire (juste Bash) — tests compris
* **Bug driven development** : chaque bug rencontré devient un test (voir `CHANGELOG.md`)

---

## 📄 License

**MIT License**
(c) 2025 Seb

Tu es libre d’utiliser, modifier et distribuer CoolBash sous licence MIT.

---

## 💡 Tagline

> “Cool defaults for a hot terminal.” 🔥

---

🧊 CoolBash — Make your Bash cool again !
