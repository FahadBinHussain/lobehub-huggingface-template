# Repo Notes

- This repo is a wrapper/template around the official `lobehub/lobehub` Docker image.
- Keep upstream LobeHub source out of this repo. Prefer Docker args, Space config, env vars, and small helper scripts.
- Do not commit `.env*`, tokens, Hugging Face profiles, OAuth secrets, browser profiles, or exported service credentials.
- Keep the Hugging Face Space, GitHub repo, and deployment name symmetric: `lobehub-huggingface-template`.
