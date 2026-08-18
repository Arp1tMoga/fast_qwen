# fast_qwen — Qwen3.8-27B MTPLX Optimized Speed (chunked for GitHub)

Chunked upload of `Youssofal/Qwen3.8-27B-MTPLX-Optimized-Speed` for GitHub's 100 MB per-file limit.

- **Source:** `Youssofal--Qwen3.8-27B-MTPLX-Optimized-Speed` (20.4 GB declared in `model.safetensors.index.json`)
- **Quant:** 4-bit dynamic (bulk) + 8-bit head/embed/GDN out_proj + bf16 norms/MTP head
- **Chunking:** `split -b 90M` → ≤90 MB parts, 10 MB margin under GitHub's 100 MB hard limit
- **Large files (chunked):** 6 files → 228 parts total (see `manifest.json`)

| File | Size | Parts | SHA256 |
|------|------|-------|--------|
| model-00001-of-00004.safetensors | 5355017068 | 57 | aed435f4011667af7772fee7ccec90c8... |
| model-00002-of-00004.safetensors | 5326635766 | 57 | 3f1960306e36255b7f0c7e80c742f03d9... |
| model-00003-of-00004.safetensors | 5362328225 | 57 | 6525c0edae616c0f62b69fc190268c69... |
| model-00004-of-00004.safetensors | 3478828572 | 37 | cef192620e5ecb23eaac19d2c041edc4... |
| model-vision.safetensors | 921497225 | 10 | 964bef26c740bdb6fe464b4c7c48840d... |
| mtp.safetensors | 849400403 | 10 | 4468f39621de68a19ffd0bcb2e2e2f35... |

Small files (`config.json`, `tokenizer.json`, `model.safetensors.index.json`, etc.) are stored directly.

## Download & Reassemble

```bash
git clone https://github.com/Arp1tMoga/fast_qwen.git
cd fast_qwen
chmod +x merge_model.sh
./merge_model.sh
```

`merge_model.sh` reads `manifest.json`, `cat`s each `model_chunks/<file>.part-*` back, checks size + `sha256sum -c`.

Manual per file:
```bash
cat model_chunks/model-00001-of-00004.safetensors.part-* > model-00001-of-00004.safetensors
sha256sum -c model-00001-of-00004.safetensors.sha256
```

## Re-chunking

```bash
./split_model.sh /path/to/source /path/to/fast_qwen
```

See `UPSTREAM_README.md` for original model card.
