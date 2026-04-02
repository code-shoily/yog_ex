# YogEx Wiki

This wiki contains supplementary documentation for YogEx, the pure Elixir graph algorithm library.

## Pages

| Page | Description |
|------|-------------|
| [Interoperability](./interoperability.md) | Guide to integrating external graph libraries (libgraph, :digraph, etc.) |

## Contributing

To add a new wiki page:

1. Create a new `.md` file in this directory
2. Add an entry to the table above
3. Update `mix.exs` to include the new page in `extras`
4. Run `mix docs` to verify it appears correctly
