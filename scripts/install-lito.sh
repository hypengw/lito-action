#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'lito action: %s\n' "$*" >&2
  exit 1
}

[[ "${RUNNER_OS:-}" == "Linux" ]] || fail "only Linux runners are supported"

case "${RUNNER_ARCH:-}" in
  X64) architecture="x86_64" ;;
  ARM64) architecture="aarch64" ;;
  *) fail "unsupported runner architecture '${RUNNER_ARCH:-unknown}'" ;;
esac

[[ "${LITO_VERSION:-}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] ||
  fail "invalid Lito version '${LITO_VERSION:-}'"
[[ -n "${RUNNER_TEMP:-}" ]] || fail "RUNNER_TEMP is not set"
[[ -n "${RUNNER_TOOL_CACHE:-}" ]] || fail "RUNNER_TOOL_CACHE is not set"
[[ -n "${GITHUB_OUTPUT:-}" ]] || fail "GITHUB_OUTPUT is not set"
[[ -n "${GITHUB_PATH:-}" ]] || fail "GITHUB_PATH is not set"

for command in chmod curl mkdir mktemp mv rm rmdir sha256sum tar; do
  command -v "$command" >/dev/null 2>&1 || fail "required command '$command' was not found"
done

archive="lito-${LITO_VERSION}-linux-${architecture}.tar.gz"
checksum="${archive}.sha256"
release_url="https://github.com/litocpp/lito/releases/download/${LITO_VERSION}"
cache_version="${LITO_VERSION#v}"
tool_directory="${RUNNER_TOOL_CACHE}/lito/${cache_version}/${architecture}"
install_directory="${tool_directory}/bin"
completion_marker="${tool_directory}.complete"
executable="${install_directory}/lito"

if [[ -x "$executable" && -f "$completion_marker" ]]; then
  printf 'Using cached Lito %s for linux-%s\n' "$LITO_VERSION" "$architecture"
  printf '%s\n' "$install_directory" >>"$GITHUB_PATH"
  printf 'executable=%s\n' "$executable" >>"$GITHUB_OUTPUT"
  exit 0
fi

temporary_directory="$(mktemp -d "${RUNNER_TEMP}/lito-download.XXXXXX")"
archive_path="${temporary_directory}/${archive}"
checksum_path="${temporary_directory}/${checksum}"
staged_binary=""

cleanup() {
  rm -f -- "$archive_path" "$checksum_path"
  if [[ -n "$staged_binary" ]]; then
    rm -f -- "$staged_binary"
  fi
  rmdir -- "$temporary_directory" 2>/dev/null || true
}
trap cleanup EXIT

printf 'Downloading Lito %s for linux-%s\n' "$LITO_VERSION" "$architecture"
curl --fail --location --proto '=https' --silent --show-error \
  --output "$archive_path" "${release_url}/${archive}"
curl --fail --location --proto '=https' --silent --show-error \
  --output "$checksum_path" "${release_url}/${checksum}"

(
  cd "$temporary_directory"
  sha256sum --check "$checksum"
)

mkdir -p "$install_directory"
staged_binary="$(mktemp "${install_directory}/.lito.XXXXXX")"
tar -xOzf "$archive_path" "lito-${LITO_VERSION}-linux-${architecture}/bin/lito" \
  >"$staged_binary"
[[ -s "$staged_binary" ]] || fail "release archive does not contain bin/lito"
chmod 0755 "$staged_binary"
mv -f -- "$staged_binary" "$executable"
staged_binary=""
printf '%s\n' "$LITO_VERSION" >"$completion_marker"

printf '%s\n' "$install_directory" >>"$GITHUB_PATH"
printf 'executable=%s\n' "$executable" >>"$GITHUB_OUTPUT"
