# 🧊 CoolBash

[![CI](https://github.com/yrbane/coolbash/actions/workflows/ci.yml/badge.svg)](https://github.com/yrbane/coolbash/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-0.2.4-blue.svg)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> **Make your Bash cool again.**  
> Modern, modular, and maintainable Bash configuration — the *cool* way 😎

---

## 🚀 Quick Install

Installe CoolBash en une seule commande :

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
🎨 **Prompt stylé** — couleurs adaptatives, emoji différents pour root et user.
⚡ **Performant** — historique partagé sans rechargement complet, prompt léger.
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
| `install`   | Installe CoolBash dans `~/.coolbash`          |
| `update`    | Met à jour depuis GitHub (clone git requis)   |
| `verify`    | Vérifie la syntaxe (+ shellcheck si présent)  |
| `test`      | Lance la suite de tests                       |
| `uninstall` | Supprime complètement CoolBash                |
| `init`      | Charge tous les modules dans le shell courant |
| `version`   | Affiche la version                            |
| `help`      | Affiche l’aide de la CLI                      |

La fonction shell `coolbash` est disponible dès que `~/.bashrc` a chargé CoolBash.
Les commandes `install`/`update`/`verify`/`test`/`uninstall` délèguent au `Makefile` du clone git,
retrouvé via `COOLBASH_REPO`, le fichier `~/.coolbash/.repo` écrit à l'installation, ou le parent du script.

---

## 🗂️ Project Structure

```
coolbash/
├─ cli/
│   └─ coolbash               # CLI principale
├─ modules/
│   ├─ 00-core.bash
│   ├─ 10-history.bash
│   ├─ 20-path-and-colors.bash
│   ├─ 30-aliases.bash
│   ├─ 31-git.bash
│   ├─ 32-network.bash
│   ├─ 33-devtools.bash
│   ├─ 34-python-venv.bash
│   ├─ 40-functions.bash
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
| `10-history.bash`         | Historique horodaté partagé entre sessions          |
| `20-path-and-colors.bash` | PATH propre, couleurs auto                          |
| `30-aliases.bash`         | Alias utiles et sûrs                                |
| `31-git.bash`             | Raccourcis Git et pager configuré                   |
| `32-network.bash`         | Commandes réseau et IP                              |
| `33-devtools.bash`        | Symfony, PHP, yt-dlp                                |
| `34-python-venv.bash`     | Helpers pour venv Python                            |
| `40-functions.bash`       | Fonctions utilitaires (`mkcd`, `extract`, `timer`…) |
| `50-prompt.bash`          | Prompt dynamique (git, venv, durée, emoji)          |
| `60-completion.bash`      | Completions Bash/Git/fzf                            |
| `70-motd.bash`            | Fortune + neofetch (affichage une fois par session) |
| `90-local-overrides.bash` | Surcharges locales (vide par défaut)                |

---

## 🖥️ Example Prompt

```bash
🐧 [14:32:10] Seb at sinceco-server  main  .venv  3s
~/projects/coolbash $
```

🔹 Emoji aléatoire par session
🔹 Couleurs dynamiques (TrueColor si supporté)
🔹 Segments : utilisateur, host, git, venv, durée, code retour

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
make verify             # bash -n + shellcheck
```

| Fichier                       | Ce qui est vérifié                                                                 |
| ----------------------------- | ---------------------------------------------------------------------------------- |
| `tests/test_cli_isolation.sh` | La CLI sourcée ne laisse **rien** dans le shell hors `COOLBASH_*` / `coolbash*` ; le garde-fou de nvm (`PREFIX`) est rejoué |
| `tests/test_cli_commands.sh`  | `help`, `version` (cohérente avec le CHANGELOG), ordre de chargement, module en échec, `coolbash` hors clone |
| `tests/test_modules.sh`       | Chaque module se charge sans erreur ni sortie parasite et renvoie 0                |
| `tests/test_make.sh`          | `make install` / réinstall / `uninstall` dans un HOME jetable, sur une copie du clone |
| `tests/test_syntax.sh`        | `bash -n` sur tout + shellcheck                                                    |

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
