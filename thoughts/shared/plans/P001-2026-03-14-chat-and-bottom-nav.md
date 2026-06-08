# PLAN 1: Chat Feature + Bottom Navigation

## Overview

Add a natural-language chat interface to the Flutter app backed by Google ADK + Gemini on the Go server. Restructure the app from a single-screen layout into a 3-tab bottom navigation with a central FAB.

## Current State Analysis

- Single `RecipeListScreen` containing meal plan strip, search, and recipe list in one `CustomScrollView`
- No routing framework — imperative `Navigator.push` only
- Riverpod for state, Dio for HTTP, freezed models
- Go backend serves REST API on `:8080` and MCP (mark3labs/mcp-go) on `:8082`
- MCP exposes 5 recipe tools over Streamable HTTP — no auth
- `RecipeService` interface has methods not yet surfaced via MCP: `AddToMealPlan`, `RemoveFromMealPlan`, `ListMealPlanRecipes`

### Key Discoveries:
- `main.dart:52` — `home:` is hardcoded to `RecipeListScreen()`
- `recipe_list_screen.dart:109-111` — `MealPlanSection` is a `SliverToBoxAdapter` child inside the recipe list scroll
- `recipe_providers.dart:118` — `RecipeListNotifier` is a `StateNotifierProvider` with pagination, search, optimistic meal plan toggle
- `api_client.dart` — Dio with auth interceptor, base URL from `ApiConfig`
- `router.go:13` — `NewRouter` takes `RecipeService` and logger, standard `http.ServeMux`
- No SSE or streaming patterns exist in the codebase yet
- Widgets inline `GoogleFonts.workSans(...)` and card decorations rather than always using centralised styles

## Desired End State

- Bottom navigation bar with 3 tabs: Recipes, Meal Plan, Chat
- Central oversized FAB (add recipe — still no-op, wired up later)
- Recipes tab: current recipe list with search (minus the meal plan strip)
- Meal Plan tab: dedicated full-screen view of meal plan recipes
- Chat tab: conversational UI where users can ask about recipes in natural language
- Go backend: new `/api/chat` SSE endpoint using Google ADK + Gemini with recipe tools
- Chat responses stream token-by-token to the Flutter client
- Chat sessions are ephemeral (in-memory, no persistence)

### How to verify:
- App launches with bottom nav, all 3 tabs functional
- Recipes tab shows search + paginated list (no meal plan section)
- Meal Plan tab shows meal plan recipes in a grid/list layout
- Chat tab allows sending messages and receiving streamed responses
- Chat can search recipes, describe ingredients, suggest meals etc. via tool use
- `curl -N -X POST localhost:8080/api/chat -d '{"message":"find me pasta recipes"}'` returns SSE stream

## What We're NOT Doing

- Chat history persistence (DB storage) — ephemeral only for now
- Authentication on the chat endpoint (matches existing MCP approach)
- Wiring up the FAB to actually create recipes
- go_router or any routing framework — keeping imperative navigation
- Replacing `mark3labs/mcp-go` — the existing MCP server stays as-is
- Defining tools twice — the ADK agent consumes the MCP tools, not bespoke wrappers

## Implementation Approach

**Go backend**: Add Google ADK + the official MCP Go SDK (`github.com/modelcontextprotocol/go-sdk`) as dependencies. The ADK agent connects to the existing mark3labs MCP server over Streamable HTTP (localhost) using `mcptoolset`. This means all 5 MCP tools (search, get, create, update, archive) are picked up automatically — add a tool to the MCP server and the chat agent inherits it for free. Two MCP libraries coexist in `go.mod`: mark3labs serves, official SDK consumes.

A `ChatHandler` accepts POST requests with a message (and optional session ID), creates/reuses an ADK runner+session, runs the agent, and streams events back as SSE.

**Flutter app**: Replace `MaterialApp.home` with a new `AppShell` widget that contains a `Scaffold` with `BottomNavigationBar` and an `IndexedStack` (to preserve tab state). Create a `ChatScreen` with a message list, text input, and SSE streaming via Dio's `responseType: ResponseType.stream`. Create a `MealPlanScreen` that promotes the existing `MealPlanSection` to a full tab. Trim `RecipeListScreen` to remove the embedded meal plan section.

---

## Phase 1: Go Backend — Chat Endpoint with ADK + MCP

### Overview
Add Google ADK + the official MCP Go SDK as dependencies. Create an ADK agent that connects to the existing mark3labs MCP server as a client via Streamable HTTP, picking up all recipe tools automatically. Expose a streaming SSE chat endpoint.

### Changes Required:

#### 1. Add dependencies
**Action**: `go get google.golang.org/adk google.golang.org/genai github.com/modelcontextprotocol/go-sdk/mcp`

This adds:
- `google.golang.org/adk` — Google Agent Development Kit
- `google.golang.org/genai` — Gemini Go SDK
- `github.com/modelcontextprotocol/go-sdk/mcp` — Official MCP Go SDK (client-side, for ADK's `mcptoolset`)

The existing `github.com/mark3labs/mcp-go` stays — it serves the MCP tools. The official SDK consumes them. Two libs, different roles, same wire protocol.

#### 2. Chat handler
**File**: `internal/application/chat/handler.go` (new)
**Purpose**: HTTP handler that accepts chat messages and streams ADK responses via SSE.

```go
package chat

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"sync"

	mcpclient "github.com/modelcontextprotocol/go-sdk/mcp/client"
	"google.golang.org/adk/agent"
	"google.golang.org/adk/agent/llmagent"
	"google.golang.org/adk/model/gemini"
	"google.golang.org/adk/runner"
	"google.golang.org/adk/session"
	"google.golang.org/adk/tool"
	"google.golang.org/adk/tool/mcptoolset"
	"google.golang.org/genai"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

type ChatHandler struct {
	runner         *runner.Runner
	sessionService session.Service
	logger         logger.Logger
}

type ChatRequest struct {
	Message   string `json:"message"`
	SessionID string `json:"session_id,omitempty"`
}

func NewChatHandler(mcpAddr string, logger logger.Logger) (*ChatHandler, error) {
	ctx := context.Background()

	// Connect to Gemini
	model, err := gemini.NewModel(ctx, "gemini-2.5-flash", &genai.ClientConfig{
		APIKey: os.Getenv("GOOGLE_API_KEY"),
	})
	if err != nil {
		return nil, fmt.Errorf("creating gemini model: %w", err)
	}

	// Connect to the existing MCP server as a client
	mcpURL := fmt.Sprintf("http://localhost%s/mcp", mcpAddr)
	transport, err := mcpclient.NewStreamableHTTP(ctx, mcpURL)
	if err != nil {
		return nil, fmt.Errorf("connecting to MCP server at %s: %w", mcpURL, err)
	}

	mcpTools, err := mcptoolset.New(mcptoolset.Config{
		Transport: transport,
	})
	if err != nil {
		return nil, fmt.Errorf("creating MCP toolset: %w", err)
	}

	// Create agent with MCP tools — all 5 recipe tools picked up automatically
	a, err := llmagent.New(llmagent.Config{
		Name:        "recipe_assistant",
		Model:       model,
		Description: "A helpful recipe assistant",
		Instruction: `You are a friendly recipe assistant for "The Bluer Book" recipe collection.
You can search for recipes, get recipe details, create new recipes, update existing ones, and archive them.
When users ask about recipes, use your tools to find real data — don't make up recipes.
Keep responses concise and conversational. Format recipe names in bold.
If a tool returns multiple recipes, summarise them briefly rather than dumping all details.
When creating or updating recipes, confirm the details with the user before proceeding.`,
		Toolsets: []tool.Toolset{mcpTools},
	})
	if err != nil {
		return nil, fmt.Errorf("creating agent: %w", err)
	}

	sessionService := session.InMemoryService()

	r, err := runner.New(runner.Config{
		AppName:        "bluer_book_chat",
		Agent:          a,
		SessionService: sessionService,
	})
	if err != nil {
		return nil, fmt.Errorf("creating runner: %w", err)
	}

	return &ChatHandler{
		runner:         r,
		sessionService: sessionService,
		logger:         logger,
	}, nil
}
```

The `HandleChat` method:
- Parses `ChatRequest` from POST body
- Creates a new session if no `session_id` provided, reuses existing otherwise
- Sets SSE headers (`Content-Type: text/event-stream`, `Cache-Control: no-cache`, `Connection: keep-alive`)
- Iterates over `runner.Run()` events with `StreamingModeSSE`
- For each event with text content, writes `data: {"content": "...", "done": false}\n\n`
- On final response, writes `data: {"content": "", "done": true, "session_id": "..."}\n\n`
- Flushes after each write

#### 3. Wire into server
**File**: `cmd/server/server.go`
**Changes**:
- Add `GOOGLE_API_KEY` env var flag
- After starting the MCP server goroutine, create `ChatHandler` passing `mcpAddr`
- The MCP server must be started *before* creating the chat handler (since the handler connects to it as a client)
- Pass the chat handler to the router

**File**: `internal/application/api/router.go`
**Changes**:
- `NewRouter` signature gains a `chatHandler *chat.ChatHandler` parameter
- Add `mux.HandleFunc("POST /api/chat", chatHandler.HandleChat)`

#### 4. Startup ordering
The MCP server needs to be listening before the chat handler tries to connect. Current code starts both servers in goroutines. New ordering:

```go
// 1. Start MCP server (already in a goroutine)
go func() {
    httpMCPServer := server.NewStreamableHTTPServer(mcpServer)
    httpMCPServer.Start(mcpAddr)
}()

// 2. Brief pause to let MCP server bind (or better: health check loop)
// Could retry the mcptoolset connection with backoff

// 3. Create chat handler (connects to MCP server as client)
chatHandler, err := chat.NewChatHandler(mcpAddr, log)

// 4. Create router with chat handler
router := api.NewRouter(recipeService, chatHandler, log)

// 5. Start HTTP server
httpServer := &http.Server{Addr: listenAddr, Handler: router}
```

A more robust approach: have `NewChatHandler` retry the MCP connection with a short backoff (e.g. 3 attempts, 500ms apart) to handle the race without a sleep.

### Success Criteria:

#### Automated Verification:
- [x] `go build ./...` compiles cleanly
- [x] `go vet ./...` passes

#### Manual Verification:
- [ ] `curl -N -X POST localhost:8080/api/chat -H 'Content-Type: application/json' -d '{"message":"what pasta recipes do you have?"}'` returns streaming SSE events
- [ ] Agent discovers and uses MCP tools (`search_recipes`, `get_recipe`, `create_recipe`, `update_recipe`, `archive_recipe`)
- [ ] Agent returns real recipe data from the database
- [ ] Subsequent request with same `session_id` maintains conversation context
- [ ] Response streams incrementally (not all at once)
- [ ] Creating/updating a recipe via chat actually persists to the database

---

## Phase 2: Flutter — Bottom Navigation Shell

### Overview
Replace the single-screen layout with a bottom navigation bar containing 3 tabs and a central FAB. Extract the recipe list into its own tab, promote meal plan to a full tab.

### Changes Required:

#### 1. App shell widget
**File**: `app/lib/application/screens/app_shell.dart` (new)
**Purpose**: Top-level scaffold with `BottomNavigationBar` and `IndexedStack`.

```dart
class AppShell extends ConsumerStatefulWidget {
  // ...
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          RecipeListScreen(),
          MealPlanScreen(),
          ChatScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex > 1 ? _currentIndex + 1 : _currentIndex,
        // Index mapping: 0=Recipes, 1=MealPlan, 2=FAB(skip), 3=Chat
        // The FAB sits in the middle, so nav items are: Recipes | MealPlan | [FAB] | Chat
        // Actually simpler: 3 items with FAB as floatingActionButton + floatingActionButtonLocation: centerDocked
        // Use BottomAppBar with notch for the FAB
        ...
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () {},
        backgroundColor: context.colours.primary,
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
```

Better approach: use `BottomAppBar` with a notch rather than `BottomNavigationBar`, since we want the FAB to sit centrally docked. The `BottomAppBar` contains a `Row` with 3 nav items (Recipes, Meal Plan, Chat) spaced around the central notch.

Actually, the cleanest Material 3 approach: `NavigationBar` with 3 destinations, plus a separate `FloatingActionButton` with `centerDocked` location using `BottomAppBar`. But `NavigationBar` and `BottomAppBar` don't compose easily.

Concrete approach:
- `Scaffold` with `extendBody: true`
- `bottomNavigationBar:` a custom `BottomAppBar` with `shape: CircularNotchedRectangle()`
- Inside: a `Row` with `IconButton`s for each tab, with a `SizedBox` gap in the middle for the FAB
- `floatingActionButton:` the big + button
- `floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked`

#### 2. Update main.dart
**File**: `app/lib/main.dart`
**Changes**: Replace `home: const RecipeListScreen()` with `home: const AppShell()`

#### 3. Trim RecipeListScreen
**File**: `app/lib/application/screens/recipe_list_screen.dart`
**Changes**: Remove the `MealPlanSection` sliver (lines 108-111). The meal plan section moves to its own tab.

#### 4. Meal Plan screen
**File**: `app/lib/application/screens/meal_plan_screen.dart` (new)
**Purpose**: Full-tab view of meal plan recipes.

A `ConsumerWidget` that watches `favouriteRecipesProvider`. Layout:
- `SliverAppBar` with title "Meal Plan"
- Grid or vertical list of `MealPlanCard` widgets (reusing existing widget, or a slightly larger variant)
- Empty state messaging
- Error state with retry

This is essentially `MealPlanSection` promoted to a full screen with vertical layout instead of horizontal scroll.

#### 5. Chat screen placeholder
**File**: `app/lib/application/screens/chat_screen.dart` (new)
**Purpose**: Placeholder for Phase 3. Just a `Scaffold` with "Chat" title and a centered "Coming soon" message. This lets us ship the nav restructure independently.

### Success Criteria:

#### Automated Verification:
- [x] `cd app && flutter analyze` passes
- [x] `cd app && flutter build web` succeeds

#### Manual Verification:
- [ ] App shows bottom nav bar with 3 tabs and central FAB
- [ ] Recipes tab shows search + recipe list (no meal plan strip)
- [ ] Meal Plan tab shows favourited recipes in a full-screen layout
- [ ] Chat tab shows placeholder
- [ ] Tab state is preserved when switching (IndexedStack)
- [ ] FAB is centred and docked into the bottom bar with notch
- [ ] Theme toggle still works
- [ ] Recipe detail navigation still works from both Recipes and Meal Plan tabs
- [ ] Dark mode looks correct on all tabs

---

## Phase 3: Flutter — Chat Screen

### Overview
Build the chat UI with message bubbles, text input, and SSE streaming from the Go backend.

### Changes Required:

#### 1. Chat service
**File**: `app/lib/infrastructure/chat_service.dart` (new)
**Purpose**: Handles HTTP communication with the chat endpoint, including SSE streaming.

```dart
class ChatService {
  final ApiClient _apiClient;

  Stream<ChatEvent> sendMessage(String message, {String? sessionId}) async* {
    final response = await _apiClient.dio.post(
      '/chat',
      data: {'message': message, 'session_id': sessionId},
      options: Options(responseType: ResponseType.stream),
    );

    // Parse SSE stream from response.data.stream
    // Yield ChatEvent objects as they arrive
  }
}

class ChatEvent {
  final String content;
  final bool done;
  final String? sessionId;
}
```

Uses Dio's `ResponseType.stream` to get a byte stream, then parses SSE `data:` lines, JSON-decodes each into `ChatEvent`.

#### 2. Chat providers
**File**: `app/lib/application/providers/chat_providers.dart` (new)

```dart
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.watch(apiClientProvider));
});

final chatMessagesProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref.watch(chatServiceProvider));
});
```

`ChatNotifier` manages:
- `List<ChatMessage>` state (user messages + assistant messages)
- `sendMessage(String text)` — adds user message, calls service, accumulates streamed tokens into assistant message, marks complete when done
- `sessionId` — stored from first response, sent with subsequent requests
- `isStreaming` getter — whether a response is currently being received
- `clearChat()` — resets messages and session

`ChatMessage` model:
```dart
class ChatMessage {
  final String content;
  final bool isUser;
  final bool isComplete;
  final DateTime timestamp;
}
```

No need for freezed here — this is ephemeral UI state, not API data.

#### 3. Chat screen (replace placeholder)
**File**: `app/lib/application/screens/chat_screen.dart`
**Purpose**: Full chat UI.

Layout:
- `Scaffold` with `SliverAppBar` titled "Chat" with a "New chat" action button
- `ListView.builder` (reversed) for messages, scrolled to bottom
- Each message is a bubble widget — user messages right-aligned in primary colour, assistant messages left-aligned in surface colour
- Assistant messages that are still streaming show a subtle typing indicator / cursor
- Text input at the bottom: `TextField` with send button, disabled while streaming
- Empty state: a friendly prompt like "Ask me about recipes..."

Styling follows existing conventions:
- Card-like bubbles using `context.colours.surface` / `context.colours.primary`
- `GoogleFonts.workSans()` for text
- `Spacing.*` constants for padding
- Markdown rendering for assistant responses (bold recipe names etc.) — use `flutter_markdown` package or just handle `**bold**` manually with `Text.rich`

#### 4. Add dependencies
**File**: `app/pubspec.yaml`
**Changes**: No new dependencies strictly needed. Dio already supports streaming. If we want markdown rendering, add `flutter_markdown`.

### Success Criteria:

#### Automated Verification:
- [x] `cd app && flutter analyze` passes
- [x] `cd app && flutter build web` succeeds

#### Manual Verification:
- [ ] Chat tab shows input field and empty state prompt
- [ ] Typing a message and sending shows it as a user bubble
- [ ] Assistant response streams in token-by-token
- [ ] Multiple messages in a conversation maintain context (same session)
- [ ] "New chat" button clears history and starts fresh session
- [ ] Send button disabled while streaming
- [ ] Messages scroll to bottom on new content
- [ ] Dark mode renders correctly
- [ ] Long messages wrap properly
- [ ] Tool use is transparent to user (they see the final answer, not raw tool calls)

---

## Testing Strategy

### Unit Tests:
- Go: test SSE response format (verify `data:` line structure, JSON encoding)
- Flutter: widget test for `AppShell` tab switching

### Integration Tests:
- Go: test `/api/chat` endpoint with real MCP server + real agent (requires `GOOGLE_API_KEY` + running DB)
- This is inherently an integration test since the chat handler connects to MCP which connects to the DB

### Manual Testing Steps:
1. Send "what recipes do you have?" — should invoke `search_recipes` and return real data
2. Send "tell me about [specific recipe name]" — should invoke `get_recipe`
3. Send "create a recipe for spaghetti carbonara" — should invoke `create_recipe`, confirm details, persist to DB
4. Send "update [recipe] to use 3 eggs instead of 2" — should invoke `update_recipe`
5. Test conversation continuity — follow-up questions should reference prior context
6. Test error state — stop the backend and verify graceful failure in chat UI
7. Test all 3 tabs with dark mode

## Performance Considerations

- `IndexedStack` keeps all 3 tabs alive — acceptable for 3 tabs, avoids re-fetching recipe data when switching
- SSE streaming means the connection stays open during a response — Dio handles this fine but we should set a reasonable timeout (60s for the chat endpoint specifically)
- ADK sessions are in-memory — they'll be lost on server restart, which is fine for now
- The Gemini API call is the bottleneck — streaming mitigates perceived latency

## Migration Notes

- No database changes required
- New env var: `GOOGLE_API_KEY` — needs to be added to deployment config
- New Go dependencies: `google.golang.org/adk`, `google.golang.org/genai`, `github.com/modelcontextprotocol/go-sdk/mcp` (official SDK, client role only — coexists with `mark3labs/mcp-go` which remains the server)
- No breaking changes to existing API endpoints or MCP tools
- The `MealPlanSection` widget remains in the codebase (used by `MealPlanScreen`) but is no longer embedded in `RecipeListScreen`
- Startup ordering changes: MCP server must start before HTTP server (chat handler connects to MCP on init)

## References

- Google ADK for Go docs: https://google.github.io/adk-docs/
- `cmd/server/server.go` — server bootstrap
- `internal/application/api/router.go` — route registration
- `internal/domain/recipe/service/recipe_service.go` — service interface
- `app/lib/main.dart` — Flutter entry point
- `app/lib/application/screens/recipe_list_screen.dart` — current home screen
- `app/lib/application/widgets/meal_plan_section.dart` — meal plan widget to promote
