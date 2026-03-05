# Collection Analyzer (Rails)

[![CI](https://github.com/epsilva09/collection_analyzer/actions/workflows/ci.yml/badge.svg)](https://github.com/epsilva09/collection_analyzer/actions/workflows/ci.yml)
[![CD](https://github.com/epsilva09/collection_analyzer/actions/workflows/cd.yml/badge.svg)](https://github.com/epsilva09/collection_analyzer/actions/workflows/cd.yml)
[![Image Tag](https://img.shields.io/github/v/tag/epsilva09/collection_analyzer?label=image%20tag&logo=docker)](https://github.com/epsilva09/collection_analyzer/pkgs/container/collection_analyzer)

Collection Analyzer is a Ruby on Rails web app that reads character
collection data from an external Armory API and presents actionable
progress insights.

The application helps you:

- Inspect a character's collection attributes.
- Compare two characters side by side.
- Track in-progress collections by completion range.
- Identify missing materials globally and by progress bucket.
- Drill down from a material to the exact collections that still
  require it.

## Main Features

- **Character search**
  - Looks up a character and shows parsed collection attributes.
- **Character comparison**
  - Compares two characters and highlights common, unique, and numeric
      differences.
  - Runs only when both names are provided.
- **Collection progress dashboard**
  - Buckets collections into ranges: `<1%`, `1–29%`, `30–79%`, and
      `≥80%`.
  - Shows collection rewards/status and missing materials summary.
- **Materials analytics**
  - Aggregates missing materials by progress bucket and in a general
      combined view.
  - Supports click-through to see all collections that still need a
      specific material.
- **Localization**
  - Supports English and Brazilian Portuguese (`en`, `pt-BR`).
- **Shared navigation menu**
  - Standardized menu across index, compare, progress, and materials
      pages.

## Routes Overview

- `GET /armory`
  - Main search page (also available at `/`).
- `GET /armory/compare?name_a=...&name_b=...`
  - Comparison page.
- `GET /armory/progress?name=...`
  - Collection progress page.
- `GET /armory/materials?name=...`
  - Missing materials dashboard.
- `GET /armory/materials/collections?name=...&material=...`
  - Collections that still need a selected material.

## Quick Start

### Prerequisites

- Ruby (project-managed version)
- Bundler
- PostgreSQL (default local database)

### Start PostgreSQL

Option 1 (local service):

```bash
# Ubuntu/Debian
sudo service postgresql start
```

Option 2 (Docker):

```bash
docker rm -f collection-analyzer-postgres >/dev/null 2>&1 || true
docker run -d \
  --name collection-analyzer-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=collection_analyzer_development \
  -p 5432:5432 \
  postgres:16
```

Option 3 (Docker Compose, recommended):

```bash
docker compose up -d postgres
```

### Install

Default local credentials used by this project are:

```bash
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=postgres
```

If your local Postgres credentials differ from defaults, set:

```bash
export DB_HOST=127.0.0.1
export DB_PORT=5432
export DB_USERNAME=postgres
export DB_PASSWORD=postgres
```

Then install and prepare the database:

```bash
cd /home/epsilva09/projects/collection_analyzer
bundle install
bin/rails db:prepare
```

### Run locally

```bash
DB_HOST=127.0.0.1 DB_PORT=5432 DB_USERNAME=postgres DB_PASSWORD=postgres bin/dev
```

When running `bin/rails server` in `development`, the app now tries to
auto-start PostgreSQL via `docker compose up -d postgres` if the database
is not reachable.

To disable this behavior for a session:

```bash
AUTO_START_POSTGRES=0 bin/rails server
```

When `foreman` is available, `bin/dev` starts both web and jobs processes
from `Procfile.dev`.

If `foreman` is not installed, `bin/dev` starts only the web server and
prints guidance to run jobs separately.

Install foreman (optional, recommended):

```bash
gem install foreman
```

Or via package manager:

```bash
# Ubuntu/Debian
sudo apt-get install foreman

# macOS (Homebrew)
brew install foreman
```

Alternative (without foreman):

```bash
DB_HOST=127.0.0.1 DB_PORT=5432 DB_USERNAME=postgres \
DB_PASSWORD=postgres bin/rails server -b 0.0.0.0 -p 3000
# in another terminal
bin/jobs
```

Open:
[http://localhost:3000](http://localhost:3000)

### Stop local PostgreSQL

Docker container mode:

```bash
docker rm -f collection-analyzer-postgres
```

Docker Compose mode:

```bash
docker compose down
```

## Configuration

- `ASC_API_BASE_URL`
  - Optional. Overrides the external API base URL used by `ArmoryClient`.

## How to Use the App

1. Open the **Search** page and enter a character name.
1. Use the menu to navigate to **Progress** (collection completion ranges),
   **Materials** (grouped missing materials), or **Compare** (compare two
   characters).
1. In **Materials**, click a material row to open the detail page
    showing where that material is still required.

## Code Structure (Key Files)

- `app/services/armory_client.rb`
  - Encapsulates all external API requests.
- `app/services/attribute_parser.rb`
  - Normalizes and parses collection attribute values.
- `app/controllers/armories_controller.rb`
  - Main controller for index, compare, progress, materials, and
      material collections.
- `app/views/armories/*.html.erb`
  - UI pages and shared menu partial.

## Quality and Security

### Tests

```bash
DB_HOST=127.0.0.1 DB_PORT=5432 DB_USERNAME=postgres \
DB_PASSWORD=postgres bin/rails test
```

### Troubleshooting (PostgreSQL)

- Error `PG::ConnectionBad` / `Connection refused`:
- Check if Postgres is running:

```bash
pg_isready -h 127.0.0.1 -p 5432 -U postgres
```

- If using Docker, verify container status:

```bash
docker ps --filter name=collection-analyzer-postgres
```

### Tests (JavaScript)

```bash
npm run test:js
```

### Lint (RuboCop)

```bash
bin/rubocop
```

### Lint (Markdown)

```bash
bundle exec rake lint:md
```

Runs markdown checks for `README.md`, `docs/**/*.md`, and
`.github/**/*.md` using `.mdl_style.rb`.

### Auto-correct (safe)

```bash
bin/rubocop -a
```

### Security scan (Brakeman)

```bash
bin/brakeman
```

## CI and CD

- **CI**: `.github/workflows/ci.yml`
  - Runs on `push` and `pull_request`.
  - Includes security checks (`brakeman`, `importmap audit`), lint,
      and test suite.
- **CD**: `.github/workflows/cd.yml`
  - Runs on pushes to `main` and `workflow_dispatch`.
  - Builds and publishes a Docker image to GHCR.

### CI Jobs

- `scan_ruby`: runs `bin/brakeman --no-pager`
- `scan_js`: runs `bin/importmap audit`
- `lint_ruby`: runs `bin/rubocop -f github`
- `lint_markdown`: runs `bundle exec rake lint:md`
- `test`: runs `bin/rails db:test:prepare test test:system`

Published image:

```bash
docker pull ghcr.io/epsilva09/collection_analyzer:latest
```

## Notes

- This project is read-only from the app perspective.
- It analyzes remote API data and local calculations.
- If the external API is unavailable, pages return graceful error
  feedback in the UI.

## Engineering Notes

- Recent implementation summary and DoD checklist:
  - [docs/engineering-changelog-2026-03.md](docs/engineering-changelog-2026-03.md)
- Development cycle template (must be filled for every cycle):
  - [docs/engineering-cycle-template.md](docs/engineering-cycle-template.md)
- Pull request template with DoD and cycle record:
  - [.github/pull_request_template.md](.github/pull_request_template.md)
- UI identity and consistency guide:
  - [docs/ui-identity-guidelines.md](docs/ui-identity-guidelines.md)
