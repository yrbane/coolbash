# shellcheck shell=bash
# FR : messages traduits. Le source est écrit en français ; quand la langue de
#      l'utilisateur n'est pas le français (COOLBASH_LANG, sinon LC_ALL,
#      LC_MESSAGES, LANG), share/lang/<langue>.bash est chargé : une table
#      COOLBASH_MSG[« texte français »]=« traduction ». Un texte absent de la
#      table reste en français — rien ne casse jamais. C et POSIX = français.
#      Ce fichier est sourcé par la CLI, par 00-core (shell) et par setup.
declare -gA COOLBASH_MSG

# FR : _coolbash_lang_init [dossier share/lang] — une seule fois par shell.
_coolbash_lang_init() {
  [[ -n "${COOLBASH_LANG_LOADED:-}" ]] && return 0
  COOLBASH_LANG_LOADED=1
  local l="${COOLBASH_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}" d="${1:-}"
  l="${l%%[._@]*}"
  l="${l,,}"
  case "$l" in
    "" | c | posix | fr*) COOLBASH_LANG=fr ;;
    *) COOLBASH_LANG="${l:0:2}" ;;
  esac
  [[ "$COOLBASH_LANG" == fr ]] && return 0
  [[ -n "$d" ]] || d="${BASH_SOURCE[0]%/*}"
  if [[ -r "$d/${COOLBASH_LANG}.bash" ]]; then
    # shellcheck disable=SC1090
    source "$d/${COOLBASH_LANG}.bash"
  elif [[ -r "$d/en.bash" ]]; then
    # shellcheck disable=SC1091
    source "$d/en.bash"
  fi
  return 0
}

# FR : _coolbash_t « texte » → la traduction (ou le texte).
_coolbash_t() { printf '%s' "${COOLBASH_MSG[$1]:-$1}"; }

# FR : _coolbash_say « format » args… → printf avec le format traduit.
_coolbash_say() {
  local _cs_f="${COOLBASH_MSG[$1]:-$1}"
  shift
  # shellcheck disable=SC2059  # FR : le format est bien un format, traduit
  printf "$_cs_f" "$@"
}
true
