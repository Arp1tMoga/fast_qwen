#!/usr/bin/env bash
# Push model_chunks to GitHub in ~1GB batches with retries.
# Usage: ./push_batched.sh  (run from repo root)
# Resumes where it left off — safe to re-run.
set -euo pipefail
cd "$(dirname "$0")"

BATCH_BYTES=$(( 120 * 1024 * 1024 ))  # 120MB ~1 part — keeps pack < postBuffer, peak <600MB (was 350MB/1GB, OOM)
RETRIES=5
DELAY=10
PUSH_TIMEOUT=600

cross_stat() { stat -c%s "$1" 2>/dev/null || stat -f%z "$1"; }

push_with_retry() {
  for i in $(seq 1 $RETRIES); do
    echo "  push attempt $i/$RETRIES (timeout ${PUSH_TIMEOUT}s) ..."
    if command -v timeout >/dev/null 2>&1; then
      if timeout $PUSH_TIMEOUT git push; then
        echo "  push OK"
        return 0
      fi
      ec=$?
      if (( ec == 124 )); then
        echo "  push timed out after ${PUSH_TIMEOUT}s (stall detected)"
      fi
    else
      if git push; then
        echo "  push OK"
        return 0
      fi
    fi
    echo "  push failed, retrying in ${DELAY}s ..."
    sleep $DELAY
  done
  echo "ERROR: push failed after $RETRIES attempts. Check network and re-run ./push_batched.sh" >&2
  return 1
}

git config http.postBuffer 157286400 >/dev/null 2>&1 || true  # 150MB — enough for 120MB batch, avoids 500MB malloc OOM
git config http.lowSpeedLimit 1000 >/dev/null 2>&1 || true
git config http.lowSpeedTime 60 >/dev/null 2>&1 || true
git config pack.threads 1 >/dev/null 2>&1 || true
git config pack.window 0 >/dev/null 2>&1 || true
git config pack.compression 0 >/dev/null 2>&1 || true
git config pack.deltaCacheSize 0 >/dev/null 2>&1 || true
git config core.compression 0 >/dev/null 2>&1 || true
git config gc.auto 0 >/dev/null 2>&1 || true
git config maintenance.auto false >/dev/null 2>&1 || true

# If there are already committed but unpushed batches, push them first
ahead=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
if (( ahead > 0 )); then
  echo ">> $ahead unpushed commit(s) found — pushing first ..."
  push_with_retry
fi

while true; do
  # collect untracked + modified chunk files, sorted
  mapfile -t files < <(git ls-files --others --exclude-standard -- model_chunks/ 2>/dev/null | sort; git diff --name-only -- model_chunks/ 2>/dev/null | sort -u)
  # dedup
  if (( ${#files[@]} == 0 )); then
    echo ">> All chunks pushed. Done."
    break
  fi
  # take ~1GB batch
  batch=()
  batch_bytes=0
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    sz=$(cross_stat "$f")
    if (( batch_bytes + sz > BATCH_BYTES && ${#batch[@]} > 0 )); then
      break
    fi
    batch+=("$f")
    batch_bytes=$((batch_bytes + sz))
  done

  if (( ${#batch[@]} == 0 )); then
    echo "ERROR: no files in batch" >&2; exit 1
  fi

  mb=$((batch_bytes / 1024 / 1024))
  echo ""
  echo ">> Batch: ${#batch[@]} files, ~${mb}MB"
  echo "   ${batch[0]} ... ${batch[-1]}"

  git add "${batch[@]}"
  first=$(basename "${batch[0]}")
  last=$(basename "${batch[-1]}")
  git commit -m "chunks: $first .. $last (${#batch[@]} parts, ~${mb}MB)

Co-authored-by: CommandCodeBot <noreply@commandcode.ai>"

  push_with_retry
  echo ">> Batch pushed. Remaining: $(git ls-files --others --exclude-standard -- model_chunks/ 2>/dev/null | wc -l) chunks"
done

echo ""
echo "All done. Verify: git log --oneline | head; git ls-files | wc -l"
