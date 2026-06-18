# Lumio Server

A Rails API backend for **Lumio**, a personal knowledge assistant ("second brain"). Users capture notes, which are automatically categorized, summarized, and embedded into a vector store. They can then chat with an LLM that answers questions grounded in their own notes via retrieval-augmented generation (RAG).

## Features

- **Notes** — CRUD with automatic background embedding on create/update
- **Categories** — manual management plus AI auto-categorization (per-note and bulk)
- **Summaries** — AI-generated note summaries
- **Chat (RAG)** — conversations scoped to a selected set of notes; relevant chunks are retrieved from Pinecone and passed to the LLM as context, with source citations
- **Auth** — Devise + JWT, with token revocation on logout

## Tech Stack

- **Ruby** 3.3.3, **Rails** 8.1 (API-only)
- **PostgreSQL** (Active Record)
- **Redis** + **Sidekiq** — background jobs (embedding, summaries)
- **Pinecone** — vector search
- **OpenRouter** via [`ruby_llm`](https://github.com/crmne/ruby_llm) — LLM completions & embeddings
- **Devise** + **devise-jwt** — authentication
- **Solid Queue / Cache / Cable** — database-backed Rails adapters
- **Kamal** + **Docker** — deployment

## Getting Started

### Prerequisites

- Ruby 3.3.3 (see `.ruby-version`)
- PostgreSQL
- Redis
- API keys for [OpenRouter](https://openrouter.ai/keys) and [Pinecone](https://www.pinecone.io/)

### Setup

```bash
# Install dependencies
bin/setup

# Configure environment variables
cp .env.example .env
# then edit .env with your real values
```

### Environment variables

| Variable              | Description                                  |
| --------------------- | -------------------------------------------- |
| `OPENROUTER_API_KEY`  | OpenRouter API key for LLM/embeddings         |
| `PINECONE_API_KEY`    | Pinecone API key                              |
| `PINECONE_INDEX_HOST` | Pinecone index host URL                       |
| `REDIS_URL`           | Redis connection URL (e.g. `redis://localhost:6379/0`) |

These are loaded via `dotenv-rails` in development. **Never commit `.env` / `.envrc`** — they are gitignored.

### Database

```bash
bin/rails db:create db:migrate
```

### Running

```bash
# Web server (Puma) + Sidekiq workers, etc.
bin/dev

# or just the Rails server
bin/rails server
```

Sidekiq must be running for embeddings, summaries, and auto-categorization to process. Its web UI is mounted at `/sidekiq`.

## API

Authentication uses JWT. On `login` / `signup`, the token is returned in the `Authorization` response header; send it back as `Authorization: Bearer <token>` on subsequent requests. All endpoints except auth require authentication.

### Auth

| Method   | Path      | Description                          |
| -------- | --------- | ------------------------------------ |
| `POST`   | `/signup` | Register a new user                  |
| `POST`   | `/login`  | Log in (returns JWT in header)       |
| `DELETE` | `/logout` | Log out (revokes the JWT)            |

### Notes

| Method                   | Path                        | Description                       |
| ------------------------ | --------------------------- | --------------------------------- |
| `GET/POST`               | `/notes`                    | List / create notes               |
| `GET/PATCH/DELETE`       | `/notes/:id`                | Show / update / delete a note     |
| `GET/POST`               | `/notes/:id/summary`        | Get / generate a note summary     |
| `POST`                   | `/notes/:id/autocategorize` | Auto-categorize a single note     |
| `POST`                   | `/autocategorize_all`       | Auto-categorize all notes         |

### Categories

| Method                   | Path              | Description                  |
| ------------------------ | ----------------- | ---------------------------- |
| `GET/POST`               | `/categories`     | List / create categories     |
| `GET/PATCH/DELETE`       | `/categories/:id` | Show / update / delete       |

### Chats

| Method                   | Path                      | Description                          |
| ------------------------ | ------------------------- | ------------------------------------ |
| `GET/POST`               | `/chats`                  | List / create chats                  |
| `GET/PATCH/DELETE`       | `/chats/:id`              | Show / update / delete a chat        |
| `POST`                   | `/chats/:id/messages`     | Send a message (RAG over chat's notes) |

A chat carries a `source_note_ids` array; messages are answered using only those notes as context.

### Health

| Method | Path  | Description                  |
| ------ | ----- | ---------------------------- |
| `GET`  | `/up` | Health check (200 if booted) |

## Testing

```bash
bin/rails test
```

Code quality / security tooling:

```bash
bin/rubocop          # linting (rubocop-rails-omakase)
bin/brakeman         # static security analysis
bin/bundler-audit    # dependency vulnerability audit
```

## Deployment

Deployed as a Docker container with [Kamal](https://kamal-deploy.org). Configuration lives in `config/deploy.yml`; secrets are resolved through `.kamal/secrets`.

```bash
bin/kamal deploy
```

Production secrets (`RAILS_MASTER_KEY` and your API keys) are injected via the `env.secret` block in `config/deploy.yml` and resolved from `.kamal/secrets` — `.env`/`.envrc` are **not** used in production.
