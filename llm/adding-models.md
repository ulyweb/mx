#  Here's how to add models:

The script must be running first (so the bundled Ollama is active on port 11434), then open a second terminal and run:
```bash
curl -X POST http://localhost:11434/api/pull -H "Content-Type: application/json" -d '{"name":"MODEL_NAME","stream":true}'
```
> Replace MODEL_NAME with any model from https://ollama.com/library.

>>Examples:
# Llama 3.2 (fast, general purpose ~2GB)
```bash
curl -X POST http://localhost:11434/api/pull -H "Content-Type: application/json" -d '{"name":"llama3.2","stream":true}'
```
# Mistral (strong reasoning ~4GB)
```bash
curl -X POST http://localhost:11434/api/pull -H "Content-Type: application/json" -d '{"name":"mistral","stream":true}'
```
# Phi-3 Mini (very fast, lightweight ~2GB)
```bash
curl -X POST http://localhost:11434/api/pull -H "Content-Type: application/json" -d '{"name":"phi3","stream":true}'
```
# Check what models are already on the USB:
```bash
curl http://localhost:11434/api/tags | python3 -m json.tool
```
# Check models stored on USB directly:
```bash
ls /media/uly/PortableAI/anythingllm_data/ollama_models/manifests/registry.ollama.ai/library/
```

>> ## Models download directly to the USB at anythingllm_data/ollama_models/ because the script sets OLLAMA_MODELS to that path before launching — Ollama inherits it and stores everything there automatically.

-

● For programming + scripting + uncensored, here's my honest ranking:

---
## Top pick:

# Best coding + uncensored combo (~4.7GB)
```bash
curl -X POST http://localhost:11434/api/pull -H "Content-Type: application/json" -d '{"name":"qwen2.5-coder:7b","stream":true}'
```
#  qwen2.5-coder:7b — Alibaba's dedicated coding model. Excellent at bash, Python, JS, and system scripting. Far less censored than most coding models. Best size-to-performance ratio.

  ---
Runner up (if you have RAM):
# Stronger but larger (~9GB)
```bash
curl -X POST http://localhost:11434/api/pull -H "Content-Type: application/json" -d '{"name":"deepseek-coder-v2","stream":true}'
```
#  deepseek-coder-v2 — arguably the best coding model on Ollama. Handles complex scripts, refactoring, and multi-file logic very well. Needs more RAM though.

  ---
  Comparison:
```chart
  ┌──────────────────────────────┬───────┬───────────┬────────────┬───────────────────────────────┐
  │            Model             │ Size  │  Coding   │ Uncensored │           Best for            │
  ├──────────────────────────────┼───────┼───────────┼────────────┼───────────────────────────────┤
  │ qwen2.5-coder:7b             │ 4.7GB │ Excellent │ Yes        │ Daily scripting, bash, Python │
  ├──────────────────────────────┼───────┼───────────┼────────────┼───────────────────────────────┤
  │ deepseek-coder-v2            │ 9GB   │ Best      │ Yes        │ Complex programming tasks     │
  ├──────────────────────────────┼───────┼───────────┼────────────┼───────────────────────────────┤
  │ dolphin-llama3 (you have it) │ 5.7GB │ Good      │ Yes        │ General + light coding        │
  ├──────────────────────────────┼───────┼───────────┼────────────┼───────────────────────────────┤
  │ codellama:13b                │ 7.4GB │ Good      │ Partial    │ Older, outclassed by above    │
  └──────────────────────────────┴───────┴───────────┴────────────┴───────────────────────────────┘
```
  ---
  ### My recommendation: start with qwen2.5-coder:7b — it's the sweet spot. If you find it hitting its limits on complex tasks, upgrade to deepseek-coder-v2. You already have dolphin-llama3 for general conversation and non-coding tasks.
