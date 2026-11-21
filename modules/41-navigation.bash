# shellcheck shell=bash
#  ███    ██   █████   ██    ██
#  ████   ██  ██   ██  ██    ██
#  ██ ██  ██  ███████  ██    ██
#  ██  ██ ██  ██   ██   ██  ██
#  ██   ████  ██   ██    ████    MODULE: NAVIGATION
# ─────────────────────────────────────────────────────────────────────────────
# FR: Se déplacer et retrouver :
#     - j <motif>  : saut de dossier par fréquence (les cd sont notés dans
#                    ~/.coolbash/dirs à chaque prompt, en pur bash — pas de zoxide),
#     - bd <nom>   : remonter jusqu'au parent nommé,
#     - h <motif>  : chercher dans l'historique, avec la date,
#     - hstats [N] : tes commandes les plus fréquentes,
#     - commande introuvable : le paquet qui la fournit (pacman -F, apt-file).
#     Réglages : COOLBASH_J=0 (ne rien noter), COOLBASH_CNF=0 (pas de suggestion).

_coolbash_safe && return 0

unalias j bd h hstats 2>/dev/null

# --- j : saut par fréquence ------------------------------------------------------
# FR : une ligne par cd dans ~/.coolbash/dirs, jamais deux fois de suite le même
#      dossier. Le fichier est compacté à 500 lignes au-delà de 1000. Le score
#      d'un dossier = nombre de visites + bonus de récence (rang de la dernière).
COOLBASH_DIRS_LAST=""
_coolbash_dirs_track() {
  [[ "${COOLBASH_J:-1}" == 0 ]] && return 0
  [[ "$PWD" == "$COOLBASH_DIRS_LAST" ]] && return 0
  COOLBASH_DIRS_LAST="$PWD"
  local file="${COOLBASH_PREFIX:-$HOME/.coolbash}/dirs" lines=()
  [[ -d "${file%/*}" ]] || return 0
  printf '%s\n' "$PWD" >>"$file" 2>/dev/null || return 0
  _coolbash_readlines lines <"$file"
  if ((${#lines[@]} > 1000)); then
    printf '%s\n' "${lines[@]: -500}" >|"$file" 2>/dev/null
  fi
  return 0
}

# FR : $1 = motif (vide = tous), sortie = chemins triés par score décroissant.
_coolbash_dirs_ranked() {
  local file="${COOLBASH_PREFIX:-$HOME/.coolbash}/dirs" score d out
  [[ -r "$file" ]] || return 1
  # FR : 10 points par visite, jusqu'à 100 de bonus pour la plus récente. Le
  #      cumul par dossier se fait dans awk : bash 3.2 (macOS) n'a pas de tableau
  #      associatif. Motif passé par l'environnement (awk -v interprète les « \ »).
  out="$(
    COOLBASH_AWK_MOTIF="${1:-}" awk '
      BEGIN { m = tolower(ENVIRON["COOLBASH_AWK_MOTIF"]) }
      { line[NR] = $0 }
      END {
        for (i = 1; i <= NR; i++) {
          d = line[i]
          if (m != "" && index(tolower(d), m) == 0) continue
          s[d] += 10 + int(100 * i / NR)
        }
        for (d in s) printf "%d\t%s\n", s[d], d
      }' "$file" | while IFS=$'\t' read -r score d; do
      [[ -d "$d" ]] && printf '%s\t%s\n' "$score" "$d"
    done | sort -rn | cut -f2-
  )"
  [[ -n "$out" ]] || return 1
  printf '%s\n' "$out"
}

j() {
  _coolbash_fn_help j "$@" && return
  local motif="${1:-}" best base lmotif
  if [[ -z "$motif" ]]; then
    _coolbash_dirs_ranked | head -15
    return
  fi
  # FR : un motif qui correspond au nom du dossier lui-même prime sur un
  #      motif noyé dans le chemin.
  _coolbash_lower lmotif "$motif"
  while IFS= read -r best; do
    _coolbash_lower base "${best##*/}"
    [[ "$base" == *"$lmotif"* ]] && {
      cd -- "$best" && return 0
    }
  done < <(_coolbash_dirs_ranked "$motif")
  best="$(_coolbash_dirs_ranked "$motif" | head -1)"
  [[ -n "$best" ]] || {
    _coolbash_say 'j : aucun dossier connu ne correspond à « %s »\n' "$motif" >&2
    return 1
  }
  cd -- "$best" || return 1
}

_coolbash_j_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}" d
  COMPREPLY=()
  while IFS= read -r d; do COMPREPLY+=("${d##*/}"); done < <(_coolbash_dirs_ranked "$cur" | head -20)
}
complete -F _coolbash_j_complete j

_coolbash_prompt_command_add _coolbash_dirs_track

# --- bd : remonter jusqu'au parent nommé -----------------------------------------
bd() {
  _coolbash_fn_help bd "$@" && return
  local name="${1:-}" p="$PWD" part
  [[ -n "$name" ]] || {
    _coolbash_say 'usage : bd <nom-de-dossier-parent>\n' >&2
    return 1
  }
  # FR : nom exact d'abord, puis préfixe, en remontant depuis le parent immédiat.
  for mode in exact prefix; do
    p="${PWD%/*}"
    while [[ -n "$p" ]]; do
      part="${p##*/}"
      if [[ "$mode" == exact && "$part" == "$name" ]] || [[ "$mode" == prefix && "$part" == "$name"* ]]; then
        cd -- "$p" && return 0
      fi
      p="${p%/*}"
    done
  done
  _coolbash_say 'bd : aucun dossier parent nommé « %s »\n' "$name" >&2
  return 1
}

# FR : complétion de bd : les noms des dossiers parents du dossier courant.
_coolbash_bd_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}" p="${PWD%/*}" part
  COMPREPLY=()
  while [[ -n "$p" ]]; do
    part="${p##*/}"
    [[ -n "$part" && "$part" == "$cur"* ]] && COMPREPLY+=("$part")
    p="${p%/*}"
  done
}
complete -F _coolbash_bd_complete bd

# --- h / hstats -------------------------------------------------------------------
# FR : h <motif> — l'historique de la session (avec HISTTIMEFORMAT, donc daté),
#      filtré sans tenir compte de la casse ; sans motif, les 30 dernières.
h() {
  _coolbash_fn_help h "$@" && return
  if [[ -z "${1:-}" ]]; then
    builtin history 30
  else
    builtin history | grep -i -- "$1"
  fi
}

# FR : hstats [N] — les N (20) premières commandes de HISTFILE, avec leur part.
#      Les lignes « #epoch » de l'horodatage sont ignorées ; sudo est transparent.
hstats() {
  _coolbash_fn_help hstats "$@" && return
  local n="${1:-20}" first total=0 c
  [[ -r "${HISTFILE:-$HOME/.bash_history}" ]] || {
    _coolbash_say "hstats : pas d'historique lisible\n" >&2
    return 1
  }
  # FR : le décompte par commande se fait dans awk (pas de tableau associatif en
  #      bash 3.2) : première ligne = le total, puis « nombre<TAB>commande ».
  {
    read -r total
    ((total)) || return 0
    _coolbash_say 'Sur %d commandes :\n' "$total"
    sort -rn | head -n "$n" \
      | while IFS=$'\t' read -r c first; do printf '  %5d  %3d %%  %s\n' "$c" $((c * 100 / total)) "$first"; done
  } < <(awk '
    /^#[0-9]+$/ || NF == 0 { next }
    {
      c = $1
      if (c == "sudo" && NF > 1) c = $2
      n[c]++
      t++
    }
    END {
      print t + 0
      for (c in n) printf "%d\t%s\n", n[c], c
    }' "${HISTFILE:-$HOME/.bash_history}")
}

# --- commande introuvable -------------------------------------------------------------
# FR : bash appelle command_not_found_handle avec la commande et ses arguments.
#      Seulement en shell interactif (un script garde le comportement d'origine),
#      et sans réseau : pacman -F lit sa base locale, apt-file la sienne, et
#      Homebrew (macOS, Linuxbrew) tient la liste « formule:exécutables » dans son
#      cache — lue par awk, sans lancer brew (une seconde de Ruby à chaque faute
#      de frappe). bash < 4.0 (le /bin/bash de macOS) n'appelle pas ce crochet.
if [[ $- == *i* && "${COOLBASH_CNF:-1}" != 0 ]]; then
  command_not_found_handle() {
    local cmd="$1" pkg="" near brewdb="${HOMEBREW_CACHE:-$HOME/Library/Caches/Homebrew}/api/internal/executables.txt"
    [[ -r "$brewdb" ]] || brewdb="${HOMEBREW_CACHE:-$HOME/.cache/Homebrew}/api/internal/executables.txt"
    _coolbash_say 'bash: %s : commande introuvable\n' "$cmd" >&2
    if command -v pacman >/dev/null 2>&1; then
      pkg="$(pacman -Fq "/usr/bin/$cmd" 2>/dev/null | head -3 | tr '\n' ' ')"
      [[ -n "$pkg" ]] && _coolbash_say '  → fournie par : %s  (sudo pacman -S %s)\n' "$pkg" "${pkg%% *}" >&2
    elif command -v apt-file >/dev/null 2>&1; then
      pkg="$(apt-file search -l "bin/$cmd" 2>/dev/null | head -3 | tr '\n' ' ')"
      [[ -n "$pkg" ]] && _coolbash_say '  → fournie par : %s  (sudo apt install %s)\n' "$pkg" "${pkg%% *}" >&2
    elif [[ -r "$brewdb" ]] && command -v brew >/dev/null 2>&1; then
      pkg="$(COOLBASH_AWK_CMD="$cmd" awk -F: '
        { n = split($2, e, " "); for (i = 1; i <= n; i++) if (e[i] == ENVIRON["COOLBASH_AWK_CMD"]) { sub(/\(.*/, "", $1); print $1; break } }
      ' "$brewdb" 2>/dev/null | head -3 | tr '\n' ' ')"
      [[ -n "$pkg" ]] && _coolbash_say '  → fournie par : %s  (brew install %s)\n' "$pkg" "${pkg%% *}" >&2
    fi
    if [[ -z "$pkg" && ${#cmd} -ge 3 ]]; then
      near="$(compgen -c -- "${cmd:0:3}" 2>/dev/null | sort -u | head -5 | tr '\n' ' ')"
      [[ -n "$near" ]] && _coolbash_say '  → tu voulais dire : %s\n' "$near" >&2
    fi
    return 127
  }
fi
true
