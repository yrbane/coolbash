#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : chaque module ne laisse dans le shell que des noms autorisés.
#  FR : variables → COOLBASH_* ou variables d'environnement en MAJUSCULES
#       (configuration, ex. HISTSIZE, EDITOR, PS1) ; fonctions → _coolbash_*,
#       coolbash*, ou l'API publique documentée dans le README.
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# FR : API publique volontaire — toute nouvelle fonction ici doit être documentée dans le README.
PUBLIC_FUNCS="path_prepend path_append please nvm man mkcd extract up timer mkvenv workon"
FORBIDDEN_VARS='^(PREFIX|NPM_CONFIG_PREFIX|VERSION|MODULE_DIR|BASHRC|reset|bold|blue|yellow)$'
BASH_NOISE='^(_|PIPESTATUS|OLDPWD|BASH_REMATCH|FUNCNAME|BASH_ARGV|BASH_ARGC|BASH_LINENO|BASH_SOURCE|COMP_WORDBREAKS|COMPREPLY)$'
CORE="${COOLBASH_TEST_ROOT}/modules/00-core.bash"

for m in "${COOLBASH_TEST_ROOT}"/modules/*.bash; do
  name="$(basename "$m" .bash)"
  pre=""
  [[ "$name" != "00-core" ]] && pre="source \"${CORE}\";"
  leaks="$(MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c "
    ${pre}
    set +o noclobber
    compgen -v | sort > \"\$1/v1\"; compgen -A function | sort > \"\$1/f1\"
    source \"\$2\"
    compgen -v | sort > \"\$1/v2\"; compgen -A function | sort > \"\$1/f2\"
    comm -13 \"\$1/v1\" \"\$1/v2\" | grep -Ev \"\$3\" | grep -Ev '^COOLBASH_' | grep -Ev '^[A-Z][A-Z0-9_]*$' | sed 's/^/variable: /'
    comm -13 \"\$1/v1\" \"\$1/v2\" | grep -E \"\$4\" | sed 's/^/variable interdite: /'
    for f in \$(comm -13 \"\$1/f1\" \"\$1/f2\"); do
      case \" \$5 \" in *\" \$f \"*) continue ;; esac
      [[ \$f == _coolbash_* || \$f == coolbash* ]] || echo \"fonction: \$f\"
    done
  " _ "${COOLBASH_TEST_TMP}" "$m" "${BASH_NOISE}" "${FORBIDDEN_VARS}" "${PUBLIC_FUNCS}" 2>&1)"
  assert_empty "${name} : seulement COOLBASH_*/MAJUSCULES et _coolbash_*/API publique" "${leaks}"
done

# FR : l'API publique est documentée.
for f in ${PUBLIC_FUNCS} coolbash_log coolbash_error; do
  assert_contains "README documente ${f}" "$(cat "${COOLBASH_TEST_ROOT}/README.md")" "\`${f}\`"
done

t_done
