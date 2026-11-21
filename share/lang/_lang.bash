# shellcheck shell=bash
# FR : socle commun, sourcé avant tout le reste par la CLI, par 00-core (shell),
#      par setup et inliné dans un ~/.bashrc compilé. Deux rôles :
#
#      1. Compatibilité. CoolBash tourne de bash 3.2 (le /bin/bash de macOS, 2007)
#         à bash 5.x. Ce que bash 3.2 n'a pas (tableaux associatifs, mapfile,
#         printf %(…)T, ${x,,}) passe par les fonctions ci-dessous : la voie
#         rapide (zéro processus) quand le bash la connaît, un repli sinon.
#         Tout ce fichier doit rester lisible ET exécutable par bash 3.2.
#
#      2. Messages traduits. Le source est écrit en français ; quand la langue de
#         l'utilisateur n'est pas le français (COOLBASH_LANG, sinon LC_ALL,
#         LC_MESSAGES, LANG), share/lang/<langue>.bash est chargé : une table
#         COOLBASH_MSG[« texte français »]=« traduction ». Un texte absent de la
#         table reste en français — rien ne casse jamais. C et POSIX = français.

# --- compatibilité bash 3.2 → 5.x -----------------------------------------------
# FR : version du bash courant en un nombre : 302, 404, 503…
COOLBASH_BASH=$((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1]))

# FR : _coolbash_date <variable> <format strftime> — la date courante, sans
#      processus quand printf sait %(…)T (bash ≥ 4.2), par date(1) sinon
#      (trouvé même avec un PATH réduit).
if ((COOLBASH_BASH >= 402)); then
  # shellcheck disable=SC2059  # FR : le format est construit, c'est voulu
  _coolbash_date() { printf -v "$1" "%($2)T" -1; }
else
  _coolbash_date() { printf -v "$1" '%s' "$(PATH="${PATH}:/usr/bin:/bin" date "+$2")"; }
fi

# FR : _coolbash_readlines <tableau> — les lignes de l'entrée standard dans le
#      tableau nommé (mapfile -t, bash ≥ 4.0 ; boucle read sinon). Le tableau de
#      l'appelant ne doit pas s'appeler _rl_*.
if ((COOLBASH_BASH >= 400)); then
  _coolbash_readlines() { mapfile -t "$1"; }
else
  _coolbash_readlines() {
    local _rl_line _rl_n=0
    eval "$1=()"
    while IFS= read -r _rl_line || [[ -n "$_rl_line" ]]; do
      eval "$1[_rl_n]=\$_rl_line"
      _rl_n=$((_rl_n + 1))
    done
    return 0
  }
fi

# FR : _coolbash_lower <variable> <texte> — en minuscules (${x,,}, bash ≥ 4.0 ;
#      tr sinon, et seulement s'il y a une majuscule : pas de processus pour rien).
if ((COOLBASH_BASH >= 400)); then
  _coolbash_lower() { printf -v "$1" '%s' "${2,,}"; }
else
  _coolbash_lower() {
    case "$2" in
      *[[:upper:]]*) printf -v "$1" '%s' "$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')" ;;
      *) printf -v "$1" '%s' "$2" ;;
    esac
  }
fi

# --- messages traduits ------------------------------------------------------------
# FR : bash ≥ 4.2 : un tableau associatif (declare -g : ce fichier est parfois
#      sourcé depuis une fonction). Avant : deux tableaux parallèles, clés et
#      valeurs, parcourus à la recherche — vides en français, donc gratuits.
if ((COOLBASH_BASH >= 402)); then
  declare -gA COOLBASH_MSG
  # FR : _coolbash_t « texte » → la traduction (ou le texte).
  _coolbash_t() { printf '%s' "${COOLBASH_MSG[$1]:-$1}"; }
  # FR : _coolbash_say « format » args… → printf avec le format traduit.
  _coolbash_say() {
    local _cs_f="${COOLBASH_MSG[$1]:-$1}"
    shift
    # shellcheck disable=SC2059  # FR : le format est bien un format, traduit
    printf "$_cs_f" "$@"
  }
  # FR : _coolbash_lang_load <fichier> — charge une table.
  _coolbash_lang_load() {
    # shellcheck disable=SC1090
    source "$1"
  }
else
  COOLBASH_MSG_K=()
  COOLBASH_MSG_V=()
  # FR : _coolbash_msg <variable> « texte » — la traduction (ou le texte).
  _coolbash_msg() {
    local _m_i _m_n=${#COOLBASH_MSG_K[@]}
    for ((_m_i = 0; _m_i < _m_n; _m_i++)); do
      [[ "${COOLBASH_MSG_K[_m_i]}" == "$2" ]] || continue
      printf -v "$1" '%s' "${COOLBASH_MSG_V[_m_i]}"
      return 0
    done
    printf -v "$1" '%s' "$2"
  }
  _coolbash_t() {
    local _ct
    _coolbash_msg _ct "$1"
    printf '%s' "$_ct"
  }
  _coolbash_say() {
    local _cs_f
    _coolbash_msg _cs_f "$1"
    shift
    # shellcheck disable=SC2059
    printf "$_cs_f" "$@"
  }
  # FR : la table est écrite COOLBASH_MSG[clé]=valeur, que bash < 4 ne sait pas
  #      lire : chaque ligne est coupée au « ]= » (une clé n'en contient jamais,
  #      tests/test_lang.sh le vérifie) et ses deux moitiés, déjà entre
  #      guillemets, sont affectées aux tableaux parallèles.
  _coolbash_lang_load() {
    local _ll_line _ll_k _ll_n=${#COOLBASH_MSG_K[@]}
    while IFS= read -r _ll_line; do
      [[ "$_ll_line" == 'COOLBASH_MSG['* ]] || continue
      _ll_k="${_ll_line#COOLBASH_MSG[}"
      eval "COOLBASH_MSG_K[_ll_n]=${_ll_k%%]=*} COOLBASH_MSG_V[_ll_n]=${_ll_line#*]=}"
      _ll_n=$((_ll_n + 1))
    done <"$1"
  }
fi

# FR : _coolbash_lang_init [dossier share/lang] — une seule fois par shell.
_coolbash_lang_init() {
  [[ -n "${COOLBASH_LANG_LOADED:-}" ]] && return 0
  COOLBASH_LANG_LOADED=1
  local l="${COOLBASH_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}" d="${1:-}"
  l="${l%%[._@]*}"
  case "$l" in
    "" | [Cc] | [Pp][Oo][Ss][Ii][Xx] | [Ff][Rr]*) COOLBASH_LANG=fr ;;
    *) _coolbash_lower COOLBASH_LANG "${l:0:2}" ;;
  esac
  [[ "$COOLBASH_LANG" == fr ]] && return 0
  [[ -n "$d" ]] || d="${BASH_SOURCE[0]%/*}"
  if [[ -r "$d/${COOLBASH_LANG}.bash" ]]; then
    _coolbash_lang_load "$d/${COOLBASH_LANG}.bash"
  elif [[ -r "$d/en.bash" ]]; then
    _coolbash_lang_load "$d/en.bash"
  fi
  return 0
}
true
