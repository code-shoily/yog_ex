# Getting Started with YogEx Development

## Project Setup Complete!

Your Elixir wrapper for Yog is ready at `~/repos/elixir/yog_ex`

## Prerequisites

- **Elixir**: ~> 1.15
- **Erlang/OTP**: Compatible version (26+ recommended)
- **Gleam**: The underlying Yog library is written in Gleam and compiled to Erlang
- **Rebar3**: Required for managing the Gleam dependency (usually comes with Erlang)

## Quick Start

### 1. Fetch Dependencies

```bash
cd ~/repos/elixir/yog_ex
mix deps.get
```

This will fetch:
- `yog` (>= 1.3.0) - The core Gleam graph library
- `ex_doc` - For generating documentation (dev only)

### 2. Compile

```bash
mix compile
```

This compiles both the Elixir wrapper and the underlying Gleam Yog library.

### 3. Run Tests

```bash
mix test
```

### 4. Try Examples

The project includes 18+ comprehensive examples demonstrating various graph algorithms:

```bash
# Run a specific example
mix run examples/graph_creation.exs
mix run examples/gps_navigation.exs
mix run examples/social_network_analysis.exs

# Run multiple examples
for file in examples/*.exs; do
  echo "Running: $file"
  mix run "$file"
done
```

Available examples include:
- **Basic**: `graph_creation.exs` - 10+ ways to create graphs
- **Pathfinding**: `gps_navigation.exs`, `city_distance_matrix.exs`
- **Network Analysis**: `social_network_analysis.exs`, `task_scheduling.exs`
- **Optimization**: `network_cable_layout.exs`, `network_bandwidth.exs`, `job_matching.exs`
- **Graph Theory**: `bridges_of_konigsberg.exs`, `global_min_cut.exs`
- **Matching**: `job_assignment.exs`, `medical_residency.exs`
- **Generation**: `graph_generation_showcase.exs`
- **Rendering**: `render_dot.exs`, `render_mermaid.exs`, `render_json.exs`

See the [examples/](examples/) directory for the full list.

### 5. Interactive Development

```bash
iex -S mix
```

Then try:

```elixir
# Create a graph
graph = Yog.directed()
  |> Yog.add_node(1, "A")
  |> Yog.add_node(2, "B")
  |> Yog.add_edge(from: 1, to: 2, with: 10)

# Query it
Yog.successors(graph, 1)
#=> [{2, 10}]

# Use labeled graphs
builder = Yog.Builder.Labeled.directed()
  |> Yog.Builder.Labeled.add_edge("home", "work", 10)

graph = Yog.Builder.Labeled.to_graph(builder)
```

## Development Workflow

### Format Code

```bash
mix format
```

### Generate Documentation

```bash
mix docs
open doc/index.html
```

### Check API Synchronization

YogEx provides a custom Mix task to ensure all Gleam Yog functions are wrapped:

```bash
mix yog.sync
```

This task:
- Compares exported functions between the Gleam `:yog` module and the Elixir `Yog` module
- Reports any missing wrapper functions
- Exits with an error if wrappers are missing
- Shows a success message if everything is in sync

**Predicate Auto-Mapping**

The sync task automatically accounts for idiom differences between Gleam and Elixir concerning predicate functions. Any Gleam function beginning with `is_` (e.g. `is_directed`) is expected to be wrapped as an Elixir function ending in `?` without the prefix (e.g. `directed?`) to satisfy Elixir conventions and tools like Credo.

**Use this task when:**
- Upgrading the Yog dependency version
- Adding new wrapper functions
- Ensuring API completeness before publishing

## Working with the Gleam Dependency

### Understanding the Dependency

YogEx wraps [Yog](https://hexdocs.pm/yog), a graph algorithm library written in Gleam. Gleam compiles to Erlang bytecode, making it compatible with the BEAM ecosystem.

- **Current Yog version**: >= 1.3.0
- **Gleam documentation**: [hexdocs.pm/yog](https://hexdocs.pm/yog)
- **Gleam project repository**: [github.com/code-shoily/yog](https://github.com/code-shoily/yog)

### Keeping in Sync with Yog

When the Gleam Yog library updates:

1. **Update dependency version** in `mix.exs`:
   ```elixir
   {:yog, ">= 1.4.0", manager: :rebar3}
   ```

2. **Check for API changes**:
   ```bash
   mix deps.update yog
   mix compile
   mix yog.sync
   ```

3. **Add new wrapper functions** if needed (the sync task will tell you)

4. **Update tests** to cover new functionality

5. **Update CHANGELOG.md** with changes

### Using a Local Yog Development Version

If you're developing both YogEx and Yog simultaneously:

```elixir
# In mix.exs, change:
{:yog, ">= 1.3.0", manager: :rebar3}

# To:
{:yog, path: "../../gleam/yog", manager: :rebar3, override: true}
```

Then run:
```bash
mix deps.get
mix compile
```

## Publishing to Hex

When ready to publish:

1. **Update version** in `mix.exs` if needed
2. **Update CHANGELOG.md** with changes
3. **Run tests**: `mix test`
4. **Check sync**: `mix yog.sync`
5. **Format code**: `mix format`
6. **Build docs**: `mix docs`
7. **Build package**: `mix hex.build`
8. **Publish**: `mix hex.publish`

## Project Structure

```
yog_ex/
├── lib/
│   ├── yog.ex              # Main module (core operations)
│   └── yog/
│       ├── labeled.ex      # Labeled graph builder
│       ├── pathfinding.ex  # Shortest path algorithms
│       ├── traversal.ex    # BFS/DFS
│       ├── transform.ex    # Graph transformations
│       ├── render.ex       # Visualization (Mermaid, DOT, JSON)
│       ├── generator.ex    # Graph generation
│       ├── matching.ex     # Bipartite matching & stable marriage
│       ├── connectivity.ex # Bridges, articulation points, SCCs
│       ├── eulerian.ex     # Eulerian paths & circuits
│       ├── disjoint_set.ex # Union-Find data structure
│       └── priority_queue.ex # Pairing heap
├── lib/mix/tasks/
│   └── yog.sync.ex         # API sync checker
├── test/
│   ├── yog_test.exs
│   └── yog_labeled_test.exs
├── examples/               # 18+ comprehensive examples
├── mix.exs
├── README.md
├── GETTING_STARTED.md
├── CHANGELOG.md
└── LICENSE
```

## Common Tasks

### Run All Examples

```bash
for example in examples/*.exs; do
  echo "=== Running $example ==="
  mix run "$example"
  echo ""
done
```

### Run Tests with Coverage

```bash
mix test --cover
```

### Check for Compilation Warnings

```bash
mix compile --warnings-as-errors
```

### Clean Build Artifacts

```bash
mix clean
mix deps.clean --all
mix deps.get
mix compile
```

## Development Tips

### Gleam-Erlang Interoperability

YogEx functions call Gleam-compiled Erlang modules directly:

```elixir
# Elixir wrapper
def directed, do: :yog.directed()

# Calls the Gleam-compiled :yog Erlang module
```

Gleam types map to Erlang/Elixir types:
- `List(a)` → Erlang list
- `Option(a)` → `:some` / `:none` atoms
- `Result(a, e)` → `{:ok, value}` / `{:error, reason}`
- `#(a, b)` → Erlang tuple

### Testing Locally

Use path dependencies during development:

```elixir
# mix.exs
defp deps do
  [
    {:yog, path: "../../gleam/yog", manager: :rebar3, override: true}
  ]
end
```

### CI/CD

Consider setting up GitHub Actions:

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      - run: mix deps.get
      - run: mix compile --warnings-as-errors
      - run: mix test
      - run: mix format --check-formatted
      - run: mix yog.sync
      - run: mix docs
```

## Troubleshooting

### Compilation Errors

If you see Gleam-related compilation errors:

```bash
mix deps.clean yog
mix deps.get
mix compile
```

### Missing Rebar3

On some systems, you may need to install Rebar3 separately:

```bash
# macOS
brew install rebar3

# Ubuntu/Debian
apt-get install rebar3
```

### API Sync Failures

If `mix yog.sync` reports missing functions:

1. Check the [Yog documentation](https://hexdocs.pm/yog) for the new functions
2. Add wrapper functions to the appropriate YogEx module
3. Follow the existing pattern for wrapping Gleam functions
4. Run `mix yog.sync` again to verify

## Resources

- **YogEx Documentation**: [hexdocs.pm/yog_ex](https://hexdocs.pm/yog_ex/)
- **Yog (Gleam) Documentation**: [hexdocs.pm/yog](https://hexdocs.pm/yog)
- **Yog GitHub Repository**: [github.com/code-shoily/yog](https://github.com/code-shoily/yog)
- **YogEx GitHub Repository**: [github.com/code-shoily/yog_ex](https://github.com/code-shoily/yog_ex)
- **Gleam Language**: [gleam.run](https://gleam.run)
- **Examples**: See [examples/](examples/) directory for practical use cases

## Questions?

- Check [Yog (Gleam) documentation](https://hexdocs.pm/yog) for algorithm details
- See [examples/](examples/) for practical usage patterns
- Open an issue on [GitHub](https://github.com/code-shoily/yog_ex/issues)

Happy graphing!
