# The Bluer Book

Personal recipe book with MCP integration for LLM assistants.

Named after the little blue book we keep recipes in at home.

## What it is

Go backend serving a web UI for managing recipes. Built with PostgreSQL, Alpine.js, and Bootstrap. Includes an MCP server so Claude (or other LLM assistants) can search, create, update, and archive recipes programmatically.

## Architecture

- **Domain-driven design**: Recipe domain with service layer
- **API**: REST endpoints for the web UI
- **MCP Server**: Model Context Protocol integration for LLM tools
- **Storage**: PostgreSQL with sqlc-generated queries
- **Frontend**: Server-rendered templates with Alpine.js for interactivity

## Current features

- Recipe CRUD operations (web UI + MCP)
- Tag/label filtering
- Pagination
- Meal plan support (basic)
- Archive/unarchive functionality

## Long-term vision

- LLM-powered semantic search
- Cooking mode with timers
- Shopping lists
- Photo uploads
- Mobile app (Flutter/React Native)
- Voice-driven interactions
