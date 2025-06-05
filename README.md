# The Blue(r) Book

## 🚀 Quick Start

### Prerequisites:
- [Docker](https://docs.docker.com/get-docker/) (required for devcontainers)
- [Visual Studio Code](https://code.visualstudio.com/) similar (e.g. Cursor)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) for VS Code

### Recommended VS Code Extensions

When you open the project, VS Code should prompt you to install recommended extensions (see `.vscode/extensions.json`).

- **Postgres GUI:** The [Postgres extension](https://marketplace.visualstudio.com/items?itemName=ckolkman.vscode-postgres) provides a light GUI for browsing and querying the database.
- **Go tools, Docker, Dev Containers** are also recommended for a smooth experience.

### Open in Dev Container
- Open the folder in VS Code.
- When prompted, "Reopen in Container" (or use the green bottom-left icon > "Reopen in Container").
- VS Code will build and start the container with all dependencies (Postgres, Go, etc.) ready to go.

## 🐘 Database & Schema

- The schema lives in `migrations/01_schema.sql`.
- You can edit this file directly to add or modify tables, columns, etc.
- The Postgres container runs migrations automatically from the `init` folder.

### Resetting the Database

- To get a fresh database (e.g., after changing migrations):
  1. **Stop and remove the running Postgres container:**
     ```sh
     docker compose down -v
     ```
  2. **Start it again:**
     ```sh
     docker compose up -d
     ```
  This will recreate the database and re-run all migrations from scratch.

> **Note:**
> When using devcontainers, Docker commands inside the devcontainer control the host's Docker engine (via Docker socket mounting). This is safe and common. If your devcontainer is defined in the same `docker-compose.yml`, running `docker compose down` will also stop your devcontainer (just reopen it in VS Code).

## 🏗️ Running sqlc

After modifying SQL queries in `internal/infrastructure/storage/queries/`, generate the corresponding Go code using one of these methods:

1. **Command Palette (F1 or Ctrl+Shift+P):**
   - Type "Tasks: Run Task"
   - Select "sqlc generate"

2. **Keyboard Shortcut:**
   - Press Ctrl+Shift+B (default shortcut for running the default build task)

3. **Terminal:**
   ```sh
   sqlc generate
   ```

The generated code will appear in `internal/infrastructure/storage/db/`.
