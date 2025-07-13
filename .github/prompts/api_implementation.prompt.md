---
mode: agent
description: "A prompt to guide the implementation of the API server and recipe import endpoint."
---

# Task: Implement the API Server and Recipe Import Endpoint

Based on the existing project structure, implement a new `server` command to run an HTTP API server. This server will expose an endpoint for importing recipes.

## 1. Create the `server` Command

- Create a new directory: `cmd/server`.
- Inside this directory, create a file `server.go`.
- In `cmd/server/server.go`, define and export a `cli.Command` named `Command`.
- This command should have:
  - **Name**: `server`
  - **Usage**: "Start the HTTP API server"
  - **Flags**:
    - A `cli.StringFlag` for `--listen-addr` with a default value of `:8080` and an environment variable `LISTEN_ADDR`.
  - **Action**: A function `run(c *cli.Context) error` that will contain the server setup logic.

## 2. Register the Command in `main.go`

- Modify `main.go` to import the new `cmd/server` package.
- Add `server.Command` to the `Commands` slice in the `cli.App` definition.

## 3. Implement the Server Initialization Logic in `cmd/server/server.go`

- In the `run` function:
  - Get the `--db-dsn` and `--listen-addr` values from the `cli.Context`.
  - Initialize the logger.
  - Establish a database connection using the DSN.
  - Instantiate the necessary dependencies:
    - `internal/infrastructure/storage/repository/recipes.go`
    - `internal/domain/recipe/service/normalisation_service.go`
  - Create a new "import service" that orchestrates the normalization and repository calls.

## 4. Implement the HTTP Router and Handlers

- Create a new package `internal/application/api`.
- In `internal/application/api/router.go`, define the HTTP routes using `http.ServeMux`.
  - Define a route `POST /api/recipes/import` and map it to an import handler.
- In `internal/application/api/import_handler.go`:
  - Define the `ImportRecipeHandler`.
  - It should decode the JSON request body.
  - Call the import service.
  - On success, respond with `http.StatusCreated` and the created recipe as JSON.
  - On failure, respond with a JSON error and an appropriate status code (`400` or `500`).

## 5. Start the HTTP Server

- In `cmd/server/server.go`'s `run` function:
  - Set up the router and handlers.
  - Start the server using `http.ListenAndServe`.
  - Log the listening address.
  - Implement graceful shutdown to handle `SIGINT` and `SIGTERM`.

Refer to the existing files for context on how dependencies are structured and initialized.

- `main.go`
- `cmd/importer/import.go`
- `internal/infrastructure/storage/repository/recipes.go`
- `internal/domain/recipe/service/normalisation_service.go`
