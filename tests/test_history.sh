#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : module 10-history — les secrets restent hors de l'historique (HISTIGNORE).
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CORE="${COOLBASH_TEST_ROOT}/modules/00-core.bash"
HIST="${COOLBASH_TEST_ROOT}/modules/10-history.bash"
export MOTD_DISABLE=1

# FR : un vrai shell interactif (-i) alimenté par un tube : c'est lui qui applique
#      HISTIGNORE à chaque ligne saisie. `history` est lui-même ignoré.
typed() {
  printf 'source "%s"; source "%s"\n%s\nHISTTIMEFORMAT= builtin history\n' "${CORE}" "${HIST}" "$1" \
    | env "${@:2}" HOME="${COOLBASH_TEST_TMP}" HISTFILE="${COOLBASH_TEST_TMP}/hist" bash --norc --noprofile -i 2>/dev/null
}
out="$(typed $'export API_KEY=abc123\nexport GITHUB_TOKEN=ghp_x\nmysql --password secret1 db\ncurl -H "Authorization: Bearer eyJ" url\nAWS_SECRET_ACCESS_KEY=k aws s3 ls\necho hello world')"
assert_not_contains "API_KEY= n'est pas enregistré" "${out}" "abc123"
assert_not_contains "GITHUB_TOKEN= non plus" "${out}" "ghp_x"
assert_not_contains "--password x non plus" "${out}" "secret1"
assert_not_contains "Bearer x non plus" "${out}" "eyJ"
assert_not_contains "AWS_SECRET_ACCESS_KEY= non plus" "${out}" "aws s3 ls"
assert_contains "une commande ordinaire est bien enregistrée" "${out}" "echo hello world"
assert_contains "COOLBASH_HIST_SECRETS=0 : tout est gardé" "$(typed 'export API_KEY=abc123' COOLBASH_HIST_SECRETS=0)" "abc123"
assert_contains "la casse n'y change rien (Password=)" "$(typed 'echo x; Password=hunter2 ./run' | grep -c hunter2)" "0"
assert_contains "un mot proche sans = reste (tokens dans une phrase)" "$(typed 'git commit -m "parse tokens faster"')" "parse tokens faster"

t_done
