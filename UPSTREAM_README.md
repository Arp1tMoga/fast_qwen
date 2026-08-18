---
license: apache-2.0
library_name: mlx
pipeline_tag: text-generation
base_model: Qwen/Qwen3.8-27B
base_model_relation: quantized
tags:
- mlx
- apple-silicon
- macos
- speculative-decoding
- multi-token-prediction
- qwen
- qwen3.8
- mtp
- mtplx
- local-ai
- coding
---

**[MTPLX.COM](https://mtplx.com): 2 to 3x speedup. The fastest way to run models on a Mac.**

# Qwen 3.8 27B Optimized Speed

**4-bit dynamic quant. Great coding speeds and good quality. Recommended.**

This is the model MTPLX recommends for coding on a modern Mac with 32 GB or
more. It is Qwen3.8-27B with its native multi-token-prediction head kept, so
[MTPLX](https://mtplx.com) can draft several tokens ahead and verify them in
one pass. Same model, same output distribution, a lot more tokens per second.

## Speeds

Measured on an M5 Max, fans verified at max, single stream, generation running
to the model's own stop, official Qwen 3.8 sampling (temperature 1.0, top-p
0.95, top-k 20).

| Run | tok/s |
|---|---|
| Coding task, medium reasoning, `mtplx serve` | 58.7 |
| Same task inside the MTPLX Mac app | 55.5 |
| Long reasoning at xhigh, 28k and 20k token answers | 35.1 and 37.3 |

For context on the same night and the same task: the previous MTPLX flagship,
Qwen 3.6 27B Optimized Speed V2, ran 59.9 to 60.1 tok/s, and oMLX 0.5.7 with
its own Qwen 3.8 4-bit MTP quant ran 63.3 tok/s. MTPLX Bare Speed ran 65.2 on
that task; this build gives up a few tok/s to be much closer to the original
model.

Draft acceptance on the coding task by depth: 0.95, 0.88, 0.80. Verify cost
50 to 53 ms per round.

## How it is built

A dynamic 4-bit quant, the same hand-tuned layout as our Qwen 3.6 Optimized
Speed V2:

- The bulk of the model is 4-bit with 32-weight groups.
- The parts that hurt most at 4-bit are kept at 8-bit: the embeddings, the
  output head, all 48 GDN output projections, and the last 8 MLP blocks.
- Sensitive parts stay 16-bit: the GDN convolution kernels and recurrent state
  parameters, every norm, and the whole MTP head.
- KL divergence to the original bf16 model on our coding battery: 0.0220. That
  is 1.7x closer to the original than the flat 4-bit Bare Speed build.

| | |
|---|---|
| Download | 20.4 GB |
| Peak unified memory (measured, this artifact) | 23.6 GB |
| Context window | 262,144 tokens |
| MTP depth | 3 |
| Sampling | temperature 1.0, top-p 0.95, top-k 20 (the official Qwen 3.8 contract) |

The tuned depth and draft settings ship inside `mtplx_runtime.json`. MTPLX
reads them on load. No flags needed. Reasoning effort levels (xhigh, medium,
low) work, and preserved thinking flows through the MTP path like any other
tokens.

Speculation in MTPLX is exact. Drafts are accepted with the probability-ratio
rule plus residual resampling, so what you sample is what the model would have
sampled without speculation, at any temperature.

## Use it

Mac app: download at [mtplx.com](https://mtplx.com), pick "Qwen 3.8 27B
Optimized Speed". It is the default on modern Macs.

Command line:

```bash
pip install mtplx
mtplx serve --model Youssofal/Qwen3.8-27B-MTPLX-Optimized-Speed
```

Then point OpenCode, Pi, Claude Code, Cline, or anything that speaks the OpenAI
or Anthropic API at `http://127.0.0.1:8000`.

Siblings: [Bare Speed](https://huggingface.co/Youssofal/Qwen3.8-27B-MTPLX-Bare-Speed)
(quickest burst chat speeds, lower quality) and
[Optimized Quality](https://huggingface.co/Youssofal/Qwen3.8-27B-MTPLX-Optimized-Quality)
(8-bit, perfect quality). On an M1 or M2 Mac use the
[FP16 build](https://huggingface.co/Youssofal/Qwen3.8-27B-MTPLX-Optimized-Speed-FP16)
of this model.
