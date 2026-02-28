# Getting Started with YogEx Development

## Project Setup Complete! 🎉

Your Elixir wrapper for Yog is ready at `~/repos/elixir/yog_ex`

## Next Steps

### 1. Fetch Dependencies

```bash
cd ~/repos/elixir/yog_ex
mix deps.get
```

**Note**: This requires Yog v1.1.0 to be published to Hex first!

If Yog isn't published yet, you can use a local path dependency:

```elixir
# In mix.exs, change:
{:yog, "~> 1.1"}

# To:
{:yog, path: "../../gleam/yog"}
```

### 2. Compile

```bash
mix compile
```

### 3. Run Tests

```bash
mix test
```

### 4. Generate Documentation

```bash
mix docs
open doc/index.html
```

### 5. Format Code

```bash
mix format
```

### 6. Try in IEx

```bash
iex -S mix
```

Then:

```elixir
# Create a graph
graph = Yog.directed()
  |> Yog.add_node(1, "A")
  |> Yog.add_node(2, "B")
  |> Yog.add_edge(from: 1, to: 2, weight: 10)

# Query it
Yog.successors(graph, 1)
#=> [{2, 10}]

# Use labeled graphs
builder = Yog.Labeled.directed()
  |> Yog.Labeled.add_edge("home", "work", 10)

graph = Yog.Labeled.to_graph(builder)
```

## Publishing to Hex

When ready to publish:

1. **Update version** in `mix.exs` if needed
2. **Build docs**: `mix docs`
3. **Run tests**: `mix test`
4. **Build package**: `mix hex.build`
5. **Publish**: `mix hex.publish`

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
│       └── render.ex       # Visualization
├── test/
│   ├── yog_test.exs
│   └── yog_labeled_test.exs
├── mix.exs
├── README.md
├── CHANGELOG.md
└── LICENSE
```

## Development Tips

### Keep in Sync with Yog

When Yog (Gleam) updates:

1. Update dependency version in `mix.exs`
2. Check for new functions in Yog modules
3. Add corresponding wrapper functions
4. Update tests
5. Update CHANGELOG.md

### Testing Locally

Use path dependencies during development:

```elixir
# mix.exs
defp deps do
  [
    {:yog, path: "../../gleam/yog"}
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
      - uses: actions/checkout@v2
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      - run: mix deps.get
      - run: mix test
      - run: mix format --check-formatted
```

## Questions?

- Check [Yog (Gleam) docs](https://hexdocs.pm/yog)
- See examples in tests
- Open an issue on GitHub

Happy graphing! 📊✨
