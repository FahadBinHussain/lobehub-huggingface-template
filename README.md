---
title: LobeHub Hugging Face Template
sdk: docker
app_port: 3210
license: mit
---

# lobehub-huggingface-template

Thin Hugging Face Docker Space wrapper around the official `lobehub/lobehub` image.

This repo is intentionally tiny:

- Upstream LobeHub stays untouched.
- The Dockerfile uses the official published container image.
- Runtime state lives in external services, not in the Space filesystem.
- Secrets stay in Hugging Face Space settings, not in Git.
- The same external Neon, Backblaze B2/S3, Google auth, and LiteLLM-style provider setup can be reused from the Vercel deployment.

## Shape

```text
Hugging Face Space
  -> official lobehub/lobehub container
  -> external Postgres DATABASE_URL
  -> external S3-compatible storage
  -> OpenAI-compatible LiteLLM gateway
  -> Google OAuth
```

Redis is optional here. The current Vercel deployment does not have `REDIS_*` variables configured, so this wrapper keeps Redis out unless you explicitly add it later.

## Local Build

```powershell
docker build -t lobehub-huggingface-template .
```

Run locally with an uncommitted env file:

```powershell
docker run --rm -p 3210:3210 --env-file .env.local lobehub-huggingface-template
```

## Hugging Face Deploy

Create a Docker Space:

```powershell
C:\Users\Admin\Downloads\mainframe\hf-account.ps1 run ahmedtouhid88@gmail.com repos create ahmedtouhid88/lobehub-huggingface-template --type space --space-sdk docker --exist-ok
```

Upload this wrapper:

```powershell
C:\Users\Admin\Downloads\mainframe\hf-account.ps1 run ahmedtouhid88@gmail.com upload ahmedtouhid88/lobehub-huggingface-template . --type space --commit-message "Deploy LobeHub wrapper"
```

The expected public URL is:

```text
https://ahmedtouhid88-lobehub-huggingface-template.hf.space
```

Set `APP_URL` to that URL in the Space variables/secrets after the Space exists.

## Required Runtime Values

Use Hugging Face Space secrets for sensitive values:

```text
DATABASE_URL=
KEY_VAULTS_SECRET=
AUTH_SECRET=
JWKS_KEY=
AUTH_GOOGLE_ID=
AUTH_GOOGLE_SECRET=
OPENAI_API_KEY=
S3_ACCESS_KEY_ID=
S3_SECRET_ACCESS_KEY=
```

Use Hugging Face Space variables for non-secret values:

```text
APP_URL=https://ahmedtouhid88-lobehub-huggingface-template.hf.space
INTERNAL_APP_URL=http://localhost:3210
DATABASE_DRIVER=node
AUTH_SSO_PROVIDERS=google
AUTH_DISABLE_EMAIL_PASSWORD=1
OPENAI_PROXY_URL=https://your-litellm-space.hf.space/v1
ENABLED_UPLOAD=1
ENABLED_KNOWLEDGE_BASE=1
S3_ENDPOINT=https://your-s3-compatible-endpoint
S3_BUCKET=your-bucket-name
S3_REGION=your-region
S3_ENABLE_PATH_STYLE=1
S3_SET_ACL=0
```

Do not commit real values. Use `examples/space-variables.example` as a shape reference only.

## Sync Helper

If you have a local env file with the real values, sync it safely:

```powershell
.\scripts\sync-env-to-hf.ps1 `
  -HfEmail ahmedtouhid88@gmail.com `
  -SpaceId ahmedtouhid88/lobehub-huggingface-template `
  -EnvFile .\.env.local
```

The helper writes temporary split files for HF secrets and variables, uploads them through `mainframe\hf-account.ps1`, then deletes the temp files. It prints keys/counts only, never secret values.

## Notes

Hugging Face free Spaces can sleep or restart. This wrapper does not depend on local disk persistence for app data: database state goes to Postgres and files go to S3-compatible storage. If a future LobeHub feature starts requiring local disk state, add HF persistent storage deliberately and mount it to the path LobeHub expects.

The default image tag is `lobehub/lobehub:latest` so rebuilds can pick up upstream Docker updates without copying the monorepo. For stricter reproducibility, change `LOBEHUB_IMAGE` in the Docker build args to a fixed upstream tag.
