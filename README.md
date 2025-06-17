# Coder LLM Starter Kit

An example application to generate internal company newsletters using a local LLM, all running inside a [Coder](https://coder.com/) workspace.
This setup enables fast, secure, and fully offline development — with no dependency on public endpoints like ChatGPT or Claude.

## ✨ Features

- Local LLM-powered newsletter generation
- Interactive UI via [Gradio](https://github.com/gradio-app/gradio)
- Deployed [`llama-server`](https://github.com/ggml-org/llama.cpp) inside the workspace for fast inference
- [Coder template](./coder/main.tf) to run everything in an isolated, reproducible dev environment

## 🛠️ Getting Started

1. Clone the repo and set up your Coder workspace using the [`main.tf`](./coder/main.tf) template.
2. Inside your workspace, activate the virtual environment (`llama-server` is already running in the background):

   ```bash
   source venv/bin/activate
   ```
3. Run the newsletter generation app:

   ```bash
   gradio newsletter.py

   ```
4. Open the provided Gradio URL in your browser and start generating newsletters.

