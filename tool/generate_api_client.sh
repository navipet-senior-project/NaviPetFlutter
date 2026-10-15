#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SPEC="openapi/navipet-api.json"
OUT="packages/navipet_api"
SPEC_URL="${NAVIPET_OPENAPI_URL:-https://navipetbackend.onrender.com/docs/json}"

if [[ "${1:-}" == "--fetch" ]]; then
  echo "Fetching spec from ${SPEC_URL}"
  tmp="$(mktemp)"
  curl --fail --silent --show-error --max-time 90 "$SPEC_URL" -o "$tmp"
  jq . "$tmp" > "$SPEC"
fi

# Generate from a normalized copy; the committed spec stays byte-identical to
# what the backend serves. See tool/normalize_openapi.jq.
normalized="$(mktemp -t navipet-openapi).json"
trap 'rm -f "${tmp:-}" "$normalized"' EXIT
jq -f tool/normalize_openapi.jq "$SPEC" > "$normalized"

npx --yes @openapitools/openapi-generator-cli@2.15.3 generate \
  -i "$normalized" \
  -g dart \
  -o "$OUT" \
  --additional-properties=pubName=navipet_api,pubAuthor=NaviPet,pubDescription='Generated\ NaviPet\ backend\ API\ client'

# Drop generator noise that does not belong in the repo.
rm -rf "$OUT/.travis.yml" "$OUT/git_push.sh" "$OUT/test"

# Post-generation override: the generator pins an older http constraint.
# Align it with the app's http ^1.5.0 so both resolve in the root workspace.
if [[ -f "$OUT/pubspec.yaml" ]]; then
  sed -i.bak -E 's/^(  http: ).*/\1^1.5.0/' "$OUT/pubspec.yaml"
  rm -f "$OUT/pubspec.yaml.bak"
fi

(cd "$OUT" && dart pub get)
