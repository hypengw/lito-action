#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'lito action: %s\n' "$*" >&2
  exit 1
}

[[ -x "${LITO_EXECUTABLE:-}" ]] || fail "Lito executable is unavailable"

case "${LITO_ACTION_COMMAND:-}" in
  format-check)
    arguments=(format --check)
    if [[ -n "${LITO_ACTION_PACKAGE:-}" ]]; then
      arguments+=(--package "$LITO_ACTION_PACKAGE")
    fi
    "$LITO_EXECUTABLE" -C "${LITO_ACTION_WORKING_DIRECTORY:-.}" "${arguments[@]}"
    ;;
  publish)
    [[ -n "${LITO_ACTION_TOKEN:-}" ]] || fail "token input is required for publish"
    [[ -n "${RUNNER_TEMP:-}" ]] || fail "RUNNER_TEMP is not set"
    command -v python3 >/dev/null 2>&1 || fail "required command 'python3' was not found"

    config_root="$(mktemp -d "${RUNNER_TEMP}/lito-publish-config.XXXXXX")"
    cleanup() {
      rm -rf -- "$config_root"
    }
    trap cleanup EXIT

    umask 077
    mkdir -p "$config_root/lito"
    token_literal="$(LITO_TOKEN="$LITO_ACTION_TOKEN" python3 -c \
      'import json, os; print(json.dumps(os.environ["LITO_TOKEN"], ensure_ascii=False))')"
    printf '[registries.litocpp]\ntoken = %s\n' "$token_literal" \
      >"$config_root/lito/config.toml"

    arguments=(publish --registry litocpp)
    if [[ -n "${LITO_ACTION_PACKAGE:-}" ]]; then
      arguments+=(--package "$LITO_ACTION_PACKAGE")
    fi
    XDG_CONFIG_HOME="$config_root" \
      "$LITO_EXECUTABLE" -C "${LITO_ACTION_WORKING_DIRECTORY:-.}" "${arguments[@]}"
    ;;
  *) fail "command must be 'format-check' or 'publish'" ;;
esac
