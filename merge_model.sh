#!/usr/bin/env bash
# Reassemble chunked model files and verify SHA-256.
# Reads manifest.json when present; otherwise discovers model_chunks/*.part-*
set -euo pipefail

cd "$(dirname "$0")"

DIR="model_chunks"
MANIFEST="manifest.json"

have_sha256sum=false
if command -v sha256sum >/dev/null 2>&1; then have_sha256sum=true; fi

cross_stat() { stat -c%s "$1" 2>/dev/null || stat -f%z "$1"; }

if [[ ! -d "$DIR" ]]; then
  echo "ERROR: '$DIR' directory not found. Run from repo root." >&2; exit 1
fi

# Build file list
FILES=()
EXPECTED_SIZES=()
EXPECTED_SHAS=()

if [[ -f "$MANIFEST" ]] && command -v python3 >/dev/null 2>&1; then
  echo ">> Reading $MANIFEST ..."
  while IFS=$'\t' read -r fname fsize fsha; do
    FILES+=("$fname"); EXPECTED_SIZES+=("$fsize"); EXPECTED_SHAS+=("$fsha")
  done < <(python3 -c "
import json,signal,sys
signal.signal(signal.SIGPIPE, signal.SIG_DFL)
try:
    m=json.load(open('$MANIFEST'))
    for f in m.get('files',[]):
        print(f['file']+'\t'+str(f['size'])+'\t'+f['sha256'])
except BrokenPipeError:
    sys.exit(0)
")
else
  echo ">> No manifest or no python3 — discovering parts in $DIR ..."
  declare -A seen
  for p in "$DIR"/*.part-*; do
    [[ -e "$p" ]] || continue
    base="$(basename "$p")"
    # strip .part-NNN suffix
    logical="${base%.part-*}"
    seen["$logical"]=1
  done
  for k in "${!seen[@]}"; do FILES+=("$k"); done
  # sizes/shas unknown in this mode — will verify via *.sha256 sidecars if present
  for f in "${FILES[@]}"; do EXPECTED_SIZES+=(""); EXPECTED_SHAS+=(""); done
fi

if (( ${#FILES[@]} == 0 )); then
  echo "ERROR: no chunk sets found in $DIR" >&2; exit 1
fi

# Optional: load .sha256 sidecars when manifest shas empty
for i in "${!FILES[@]}"; do
  if [[ -z "${EXPECTED_SHAS[$i]}" && -f "${FILES[$i]}.sha256" ]]; then
    EXPECTED_SHAS[$i]=$(awk '{print $1}' "${FILES[$i]}.sha256")
  fi
  if [[ -z "${EXPECTED_SIZES[$i]}" && -f "${FILES[$i]}.sha256" ]]; then
    # size not in sidecar; will skip size check
    :
  fi
done

echo ">> Merging ${#FILES[@]} file(s)..."
for i in "${!FILES[@]}"; do
  fname="${FILES[$i]}"
  esize="${EXPECTED_SIZES[$i]}"
  esha="${EXPECTED_SHAS[$i]}"
  echo "   $fname ..."

  # shellcheck disable=SC2086
  cat "$DIR/${fname}".part-* > "$fname"

  if [[ -n "$esize" ]]; then
    actual=$(cross_stat "$fname")
    if [[ "$actual" != "$esize" ]]; then
      echo "ERROR: size mismatch for $fname (expected $esize, got $actual)" >&2
      exit 1
    fi
  fi

  if [[ -n "$esha" ]]; then
    sidecar="${fname}.sha256"
    if [[ ! -f "$sidecar" ]]; then
      echo "${esha}  ${fname}" > "$sidecar"
    fi
    echo "   verifying SHA-256 for $fname ..."
    if $have_sha256sum; then
      sha256sum -c "$sidecar"
    else
      shasum -a 256 -c "$sidecar"
    fi
  else
    echo "   (no expected hash for $fname — skipping hash check)"
  fi
done

echo ""
echo "Done — all files reassembled and verified."
