# Design Document: ElixirScope.Debugger.Features (elixir_scope_debugger_features)

## 1. Purpose & Vision

**Summary:** Implements advanced debugging capabilities for ElixirScope, including structural breakpoints, data flow breakpoints, and semantic watchpoints. It leverages the `elixir_scope_correlator` for AST/CPG context and `elixir_scope_ast_repo` for static analysis.

**(Greatly Expanded Purpose based on your existing knowledge of ElixirScope and CPG features):**

The `elixir_scope_debugger_features` library provides the engine for ElixirScope's revolutionary debugging paradigm. Moving beyond traditional line-based debugging, it enables developers to set breakpoints and watchpoints based on deep structural and semantic properties of their code, as understood through the Code Property Graph (CPG).

This library aims to:
*   **Enable Structural Breakpoints:** Allow developers to define breakpoints that trigger when specific AST or CPG patterns are encountered during execution (e.g., "break if any function call within this module lacks a preceding validation check on its arguments," where "validation check" is a CPG pattern).
*   **Implement Data Flow Breakpoints:** Allow breakpoints to be set on data flow paths within the CPG. For example, "break if data originating from user input reaches this specific database write operation without passing through a sanitization function." This requires integration with DFG/CPG information from `elixir_scope_ast_repo`.
*   **Provide Semantic Watchpoints:** Enable watchpoints that track variable values not just by name and scope, but by their semantic role or their flow through specific CPG structures. For instance, "watch the 'user_id' variable whenever it's involved in an authorization check CPG pattern."
*   **Integrate with Runtime Correlation:** Heavily utilize `elixir_scope_correlator` to map runtime events (function calls, variable assignments) to their CPG context, which is then used to evaluate if any advanced breakpoints or watchpoints are matched.
*   **Manage Debugging State:** Maintain the definitions of active breakpoints and watchpoints, their hit counts, and associated actions (e.g., pause execution, log data, notify AI). This state is managed by the `EnhancedInstrumentation` GenServer.
*   **Interface with Debugger UIs/Services:** Provide a `DebuggerInterface` to communicate breakpoint hits and watchpoint updates to external consumers, such as a "Cinema Debugger" UI or an AI assistant interacting via `TidewaveScope`.
*   **Leverage Static Analysis:** Use patterns and semantic information from `elixir_scope_ast_repo` (via CPG queries and pattern matching) to define and validate the conditions for advanced breakpoints.

This library is central to delivering the "Execution Cinema" experience by allowing debugging based on *what the code means and how it's structured at a deep level*, rather than just where a line number is. The ability to define breakpoints based on CPG patterns (e.g., "a function call that directly writes to a socket without an intermediate security check node in its CPG trace") is a key differentiator.

This library will enable:
*   Developers and AI assistants to set highly contextual and intelligent breakpoints.
*   Precise interruption or observation of execution based on complex code patterns and data flows.
*   A deeper understanding of runtime behavior through the lens of the CPG.
*   The `TidewaveScope` MCP to expose powerful debugging "tools" to AI assistants (e.g., "set a breakpoint if this potentially tainted data flows to a sink").

## 2. Key Responsibilities

This library is responsible for:

*   **Breakpoint & Watchpoint Management (`EnhancedInstrumentation` GenServer):**
    *   Storing definitions of structural breakpoints, data flow breakpoints, and semantic watchpoints.
    *   Validating breakpoint/watchpoint specifications against available AST/CPG information (from `elixir_scope_ast_repo`).
    *   Enabling and disabling breakpoints/watchpoints.
*   **Breakpoint Evaluation (`EventHandler`, `BreakpointManager`):**
    *   Receiving notifications of runtime events (e.g., function entry/exit, variable snapshot with `ast_node_id`) from `elixir_scope_capture_core` (specifically, its enhanced reporting functions).
    *   Using `elixir_scope_correlator` to get the CPG context for these events.
    *   Evaluating active structural breakpoints against the current CPG context and event data.
    *   Evaluating active data flow breakpoints by checking if the current event and its CPG context satisfy the data flow conditions (this might involve querying DFG/CPG from `elixir_scope_ast_repo`).
*   **Watchpoint Evaluation (`EventHandler`, `WatchpointManager`):**
    *   Tracking changes to watched variables, using CPG context to understand their semantic role.
    *   Updating watchpoint value histories.
    *   Triggering actions based on watchpoint conditions (e.g., value change, specific value pattern).
*   **Debugger Interface (`DebuggerInterface`):**
    *   Notifying external systems (debugger UIs, AI assistants via `TidewaveScope`) when a breakpoint is hit or a watchpoint condition is met.
    *   Potentially handling commands from a debugger UI (e.g., continue, step, inspect variables).
*   **Storage (`Storage`):**
    *   Using ETS to store breakpoint and watchpoint definitions, and potentially recent hit history or watchpoint values.
*   **AST Correlation for Debugging (`ASTCorrelator` submodule within this library, or direct use of `elixir_scope_correlator`):**
    *   Specifically handling the correlation needs for evaluating breakpoints against runtime events and their static CPG context.

## 3. Key Modules & Structure

The primary modules within this library will be:

*   `ElixirScope.Debugger.Features.EnhancedInstrumentation` (Main GenServer and API facade, from original `elixir_scope/capture/enhanced_instrumentation.ex`)
*   `ElixirScope.Debugger.Features.BreakpointManager` (Logic for managing and evaluating all types of breakpoints)
*   `ElixirScope.Debugger.Features.WatchpointManager` (Logic for managing and evaluating watchpoints)
*   `ElixirScope.Debugger.Features.EventHandler` (Receives event notifications and dispatches to managers)
*   `ElixirScope.Debugger.Features.Storage` (ETS-based storage for breakpoint/watchpoint definitions)
*   `ElixirScope.Debugger.Features.DebuggerInterface` (Handles communication with external debugger UIs/services)
*   `ElixirScope.Debugger.Features.ASTCorrelator` (Specific AST correlation logic needed for this library, if not fully covered by `elixir_scope_correlator`)
*   `ElixirScope.Debugger.Features.Types` (Defines structs for breakpoints, watchpoints, etc.)
*   `ElixirScope.Debugger.Features.Utils` (Local utilities)

### Proposed File Tree:

```
elixir_scope_debugger_features/
├── lib/
│   └── elixir_scope/
│       └── debugger/
│           └── features/
│               ├── enhanced_instrumentation.ex # Main GenServer
│               ├── breakpoint_manager.ex
│               ├── watchpoint_manager.ex
│               ├── event_handler.ex
│               ├── storage.ex
│               ├── debugger_interface.ex
│               ├── ast_correlator.ex     # (If specialized correlation is needed)
│               ├── types.ex
│               └── utils.ex
├── mix.exs
├── README.md
├── DESIGN.MD
└── test/
    ├── test_helper.exs
    └── elixir_scope/
        └── debugger/
            └── features/
                ├── enhanced_instrumentation_test.exs
                ├── breakpoint_manager_test.exs
                └── watchpoint_manager_test.exs
```

**(Greatly Expanded - Module Description):**
*   **`ElixirScope.Debugger.Features.EnhancedInstrumentation` (GenServer):** This is the central coordinating GenServer for advanced debugging. It holds the state of all defined breakpoints and watchpoints (likely delegating actual storage to the `Storage` module/ETS tables). It provides the public API for setting/removing/listing breakpoints and watchpoints. It may also manage subscriptions for debugger UIs.
*   **`ElixirScope.Debugger.Features.BreakpointManager`**: Contains the logic for creating, validating, and, most importantly, *evaluating* all types of breakpoints.
    *   For **structural breakpoints**, it would take the CPG context of a runtime event (from `elixir_scope_correlator`) and use `elixir_scope_ast_repo.PatternMatcher` to check if the current CPG node/context matches any active structural breakpoint patterns.
    *   For **data flow breakpoints**, it would analyze the DFG/CPG information (from `elixir_scope_ast_repo` via `elixir_scope_correlator`) associated with a runtime event involving variable assignment or use, to see if it satisfies a defined data flow condition (e.g., variable `x` now tainted, flowing to `y`).
*   **`ElixirScope.Debugger.Features.WatchpointManager`**: Manages semantic watchpoints. When a relevant variable snapshot event occurs, it uses the CPG context (from `elixir_scope_correlator`) to understand the semantic context of the variable and updates the watchpoint's value history. It checks if watchpoint conditions are met.
*   **`ElixirScope.Debugger.Features.EventHandler`**: This module could act as the entry point for notifications from `elixir_scope_capture_core` (if hooks are implemented there) or be called directly by the enhanced reporting functions in `InstrumentationRuntime.ASTReporting`. It then dispatches the event and its CPG context to `BreakpointManager` and `WatchpointManager` for evaluation.
*   **`ElixirScope.Debugger.Features.Storage`**: Manages ETS tables for storing the definitions of all active breakpoints and watchpoints, their hit counts, and potentially recent value history for watchpoints if not kept in the GenServer state directly.
*   **`ElixirScope.Debugger.Features.DebuggerInterface`**: Handles formatting breakpoint/watchpoint hit information and sending it to registered debugger UIs or services. It would also process incoming commands from these UIs (e.g., "step", "continue", "inspect variable `foo` at breakpoint `bp_123`").
*   **`ElixirScope.Debugger.Features.Types`**: Defines structs for `StructuralBreakpoint`, `DataFlowBreakpoint`, `SemanticWatchpoint`, and any related data structures needed for their specification and evaluation.

## 4. Public API (Conceptual)

Via `ElixirScope.Debugger.Features.EnhancedInstrumentation` (GenServer):

*   `start_link(opts :: keyword()) :: GenServer.on_start()`
    *   Options: `ast_repo_ref`, `correlator_ref`.
*   `set_structural_breakpoint(spec :: map()) :: {:ok, breakpoint_id :: String.t()} | {:error, term()}`
    *   `spec` includes CPG pattern, conditions.
*   `set_data_flow_breakpoint(spec :: map()) :: {:ok, breakpoint_id :: String.t()} | {:error, term()}`
    *   `spec` includes variable(s), source CPG node pattern, sink CPG node pattern, intermediate conditions.
*   `set_semantic_watchpoint(spec :: map()) :: {:ok, watchpoint_id :: String.t()} | {:error, term()}`
    *   `spec` includes variable name, CPG context/pattern for tracking.
*   `remove_breakpoint(id :: String.t()) :: :ok | {:error, :not_found}`
*   `enable_breakpoint(id :: String.t(), enable :: boolean()) :: :ok | {:error, :not_found}`
*   `list_breakpoints(type :: :all | :structural | :data_flow | :semantic_watchpoint) :: {:ok, list(map())}`
*   `get_breakpoint_details(id :: String.t()) :: {:ok, map()} | {:error, :not_found}`
*   `get_watchpoint_history(id :: String.t(), limit :: non_neg_integer()) :: {:ok, list(map())} | {:error, :not_found}`
*   `get_debugger_stats() :: {:ok, map()}`

Via `ElixirScope.Debugger.Features.DebuggerInterface` (for debugger UIs/services to call, potentially via an MCP tool):

*   `register_ui(pid :: pid()) :: :ok`
*   `unregister_ui(pid :: pid()) :: :ok`
*   `handle_command(command :: atom(), params :: map()) :: {:ok, any()} | {:error, term()}` (e.g., :continue, :step_over, :inspect_variable)

## 5. Core Data Structures

Defined in `ElixirScope.Debugger.Features.Types`:

*   **`StructuralBreakpoint.t()`**:
    `%{id: String.t(), cpg_pattern: term(), condition_script: String.t() | fun(), action: atom(), enabled: boolean(), hit_count: integer(), ast_repo_query: map()}`
*   **`DataFlowBreakpoint.t()`**:
    `%{id: String.t(), source_cpg_pattern: term(), sink_cpg_pattern: term(), tracked_data_tags: list(atom()), intermediate_conditions: list(term()), action: atom(), enabled: boolean(), hit_count: integer()}`
*   **`SemanticWatchpoint.t()`**:
    `%{id: String.t(), variable_name_pattern: String.t(), cpg_context_pattern: term(), conditions_on_value_change: list(term()), action: atom(), enabled: boolean(), history_limit: integer(), value_history: list(map())}`
*   Consumes: `ElixirScope.Events.t()`, `ElixirScope.Correlator.Types.ast_context()`.
*   Consumes: CPG data/patterns from `elixir_scope_ast_repo`.

## 6. Dependencies

This library will depend on the following ElixirScope libraries:

*   `elixir_scope_utils` (for utilities, ID generation).
*   `elixir_scope_config` (for its own operational parameters).
*   `elixir_scope_events` (to understand the structure of runtime events it processes).
*   `elixir_scope_capture_core` (its `InstrumentationRuntime.ASTReporting` module will be configured to send relevant events to this library's `EventHandler`).
*   `elixir_scope_correlator` (CRUCIAL for getting CPG context for runtime events).
*   `elixir_scope_ast_repo` (CRUCIAL for validating breakpoint patterns against CPGs, and for `BreakpointManager` to query CPG/DFG during data flow breakpoint evaluation).
*   `elixir_scope_ast_structures` (for types related to CPG patterns and queries).

It will depend on Elixir core libraries (`GenServer`, `:ets`).

## 7. Role in TidewaveScope & Interactions

Within the `TidewaveScope` ecosystem, the `elixir_scope_debugger_features` library will:

*   Be a central service providing advanced debugging logic.
*   Expose its breakpoint/watchpoint management API to `TidewaveScope` MCP tools. This allows an AI assistant to:
    *   "Set a breakpoint if data from `params` flows to `Ecto.Repo.insert` without passing through `MyApp.Sanitize.run`."
    *   "Watch the `current_user` variable whenever it's accessed within a CPG node tagged as `:authorization_check`."
*   The `DebuggerInterface` will send notifications about breakpoint hits/watchpoint changes to `TidewaveScope` (which can then forward them to the AI assistant or a UI).
*   Receive commands from the AI assistant (via `TidewaveScope` MCP tools) to control debugging sessions (e.g., continue, inspect).

## 8. Future Considerations & CPG Enhancements

*   **Conditional Breakpoints with CPG Properties:** Allow breakpoint conditions to reference properties of the CPG node where the event occurred (e.g., "break if this function call's CPG node has a complexity score > X").
*   **Predictive Breakpoints:** Use AI and CPG analysis to suggest "smart breakpoints" on potentially problematic CPG paths *before* they are executed.
*   **Distributed Debugging:** Coordinating breakpoints and watchpoints across multiple nodes in a distributed ElixirScope setup.
*   **More Sophisticated Actions:** Beyond just pausing, allow breakpoints to trigger custom Elixir code, log specific data, or send notifications to various channels.
*   **Visual CPG Breakpoint Definition:** An interface where users can click on CPG nodes/edges to define breakpoints.

## 9. Testing Strategy

*   **`ElixirScope.Debugger.Features.BreakpointManager` & `WatchpointManager` Unit Tests:**
    *   Test creation of valid and invalid breakpoint/watchpoint specifications.
    *   Mock runtime events and their CPG contexts (from a mock `elixir_scope_correlator`).
    *   Mock `elixir_scope_ast_repo` to provide CPG pattern matching results.
    *   Verify that breakpoints/watchpoints trigger correctly based on event data and CPG context.
    *   Test hit count updates and enable/disable functionality.
*   **`ElixirScope.Debugger.Features.EventHandler` Unit Tests:**
    *   Test that it correctly dispatches different event types to the appropriate managers.
*   **`ElixirScope.Debugger.Features.Storage` Unit Tests:**
    *   Test ETS operations for storing, retrieving, and deleting breakpoint/watchpoint definitions.
*   **`ElixirScope.Debugger.Features.DebuggerInterface` Unit Tests:**
    *   Test registration/unregistration of UIs.
    *   Test command handling (mocking the underlying actions).
    *   Verify correct formatting of notification messages.
*   **`ElixirScope.Debugger.Features.EnhancedInstrumentation` GenServer Tests:**
    *   Test all public API calls, ensuring correct state changes and delegation to managers.
    *   Test concurrent API calls.
*   **Integration Tests:**
    *   Test the flow: Mock `InstrumentationRuntime` event -> `EventHandler` -> `BreakpointManager` -> (Mock) `DebuggerInterface` notification.
    *   Simulate a sequence of events and verify data flow breakpoints trigger correctly based on mock CPG data flow paths.
*   **CPG-Specific Tests:** Tests where breakpoint conditions specifically rely on CPG node properties or CPG patterns, using a mock AST/CPG repo.
