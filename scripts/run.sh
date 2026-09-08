#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'lito action: %s\n' "$*" >&2
  exit 1
}

[[ -x "${LITO_EXECUTABLE:-}" ]] || fail "Lito executable is unavailable"

case "${LITO_ACTION_COMMAND:-}" in
  format-check)
    [[ -z "${LITO_ACTION_PACKAGES:-}" ]] ||
      fail "packages input is only supported for publish"
    [[ "${LITO_ACTION_PUBLISH_INTERVAL_SECONDS:-0}" == "0" ]] ||
      fail "publish-interval-seconds input is only supported for publish"
    arguments=(format --check)
    if [[ -n "${LITO_ACTION_PACKAGE:-}" ]]; then
      arguments+=(--package "$LITO_ACTION_PACKAGE")
    fi
    "$LITO_EXECUTABLE" -C "${LITO_ACTION_WORKING_DIRECTORY:-.}" "${arguments[@]}"
    ;;
  publish)
    [[ -n "${LITO_ACTION_TOKEN:-}" ]] || fail "token input is required for publish"
    [[ -z "${LITO_ACTION_PACKAGE:-}" || -z "${LITO_ACTION_PACKAGES:-}" ]] ||
      fail "package and packages inputs cannot be used together"
    [[ -n "${RUNNER_TEMP:-}" ]] || fail "RUNNER_TEMP is not set"
    command -v python3 >/dev/null 2>&1 || fail "required command 'python3' was not found"

    publish_interval="${LITO_ACTION_PUBLISH_INTERVAL_SECONDS:-0}"
    [[ "$publish_interval" =~ ^[0-9]+$ ]] ||
      fail "publish-interval-seconds must be a non-negative integer"

    publish_packages=()
    if [[ -n "${LITO_ACTION_PACKAGES:-}" ]]; then
      while IFS= read -r package; do
        package="${package%$'\r'}"
        [[ -n "$package" ]] || continue
        [[ "$package" != *[[:space:]]* ]] ||
          fail "packages input must contain one package name per line"
        publish_packages+=("$package")
      done <<<"$LITO_ACTION_PACKAGES"
      ((${#publish_packages[@]} > 0)) ||
        fail "packages input must contain at least one package name"
    elif [[ -n "${LITO_ACTION_PACKAGE:-}" ]]; then
      publish_packages+=("$LITO_ACTION_PACKAGE")
    else
      publish_packages+=("")
    fi

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

    for index in "${!publish_packages[@]}"; do
      package="${publish_packages[$index]}"
      arguments=(publish --registry litocpp)
      if [[ -n "$package" ]]; then
        arguments+=(--package "$package")
      fi
      XDG_CONFIG_HOME="$config_root" \
        "$LITO_EXECUTABLE" -C "${LITO_ACTION_WORKING_DIRECTORY:-.}" "${arguments[@]}"

      if ((index + 1 < ${#publish_packages[@]})) && [[ "$publish_interval" != "0" ]]; then
        printf 'Waiting %s seconds before publishing the next package\n' "$publish_interval"
        sleep "$publish_interval"
      fi
    done
    ;;
  *) fail "command must be 'format-check' or 'publish'" ;;
esac
