#!/usr/bin/env bash
# Split large model files into 90MB chunks for GitHub's 100MB per-file limit.
# Small files are copied directly. Generates manifest.json + per-file .sha256.
# Usage: ./split_model.sh [SRC_DIR] [DST_DIR]  (defaults to this repo)
set -euo pipefail

SRC="${1:-/home/arpit/.mtplx/models/Youssofal--Qwen3.8-27B-MTPLX-Optimized-Speed}"
DST="${2:-$(cd "$(dirname "$0")" && pwd)}"
CHUNK="90M"
THRESHOLD=$((90 * 1024 * 1024))

if [[ ! -d "$SRC" ]]; then echo "ERROR: SRC $SRC not found" >&2; exit 1; fi
mkdir -p "$DST/model_chunks"

echo ">> Source : $SRC"
echo ">> Dest   : $DST"
echo ">> Chunk  : $CHUNK  Threshold: ${THRESHOLD} bytes"
echo ""

MANIFEST_ENTRIES=()

cross_stat_bytes() {
  stat -c%s "$1" 2>/dev/null || stat -f%z "$1"
}

for f in "$SRC"/*; do
  [[ -f "$f" ]] || continue
  fname="$(basename "$f")"
  [[ "$fname" == ".gitattributes" ]] && continue
  if [[ "$fname" == "README.md" ]]; then continue; fi

  size=$(cross_stat_bytes "$f")
  if (( size > THRESHOLD )); then
    echo ">> Chunking $fname ($size bytes)..."
    sha=$(sha256sum "$f" | awk '{print $1}')
    rm -f "$DST/model_chunks/${fname}.part-"*
    split -b "$CHUNK" -d --suffix-length=3 "$f" "$DST/model_chunks/${fname}.part-"
    parts=$(ls -1 "$DST/model_chunks/${fname}.part-"* | wc -l)
    echo "   -> $parts parts  SHA256=$sha"
    echo "${sha}  ${fname}" > "$DST/${fname}.sha256"
    MANIFEST_ENTRIES+=("{\"file\":\"$fname\",\"size\":$size,\"sha256\":\"$sha\",\"parts\":$parts,\"chunk_size\":\"$CHUNK\"}")
  else
    echo ">> Copying  $fname ($size bytes) direct..."
    cp -a "$f" "$DST/$fname"
  fi
done

# Copy README source as upstream note (don't overwrite our README)
if [[ -f "$SRC/README.md" ]]; then
  cp -a "$SRC/README.md" "$DST/UPSTREAM_README.md" 2>/dev/null || true
fi

# Write manifest.json
{
  echo "{"
  echo '  "chunk_size": "'"$CHUNK"'",'
  echo '  "threshold_bytes": '"$THRESHOLD"','
  echo '  "generated_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",'
  echo '  "source": "'"$SRC"'",'
  echo '  "files": ['
  for i in "${!MANIFEST_ENTRIES[@]}"; do
    if (( i < ${#MANIFEST_ENTRIES[@]} - 1 )); then
      echo "    ${MANIFEST_ENTRIES[$i]},"
    else
      echo "    ${MANIFEST_ENTRIES[$i]}"
    fi
  done
  echo '  ]'
  echo "}"
} > "$DST/manifest.json"

echo ""
echo ">> Manifest written to $DST/manifest.json"
echo ">> Per-file .sha256 emitted to $DST/*.sha256"
echo ""

# Pre-push guard: any chunk >100MB?
echo ">> Guard: checking for any chunk >100MB..."
oversize=$(find "$DST/model_chunks" -type f -size +100M 2>/dev/null || true)
if [[ -n "$oversize" ]]; then
  echo "ERROR: oversized chunks (must be <=100MB):" >&2
  echo "$oversize" >&2
  exit 1
fi
echo ">> Guard OK — all chunks <=100MB"

echo ""
echo ">> Summary:"
ls -lh "$DST/model_chunks/" 2>/dev/null | tail -n +2 | awk '{print "   ", $9, $5}'
echo ">> Total chunks: $(ls -1 "$DST/model_chunks" 2>/dev/null | wc -l)"
echo "Done."
