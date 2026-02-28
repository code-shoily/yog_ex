# Yog Ex: AI Agent Instructions

This repository (`yog_ex`) is an Elixir wrapper around the Gleam graph algorithm library `yog`. The Gleam codebase is the **source of truth**.

When assisting with code generation, refactoring, documentation, or bug fixing in this repository, you must adhere strictly to the following rules and formatting conventions.

## 1. Module Mapping
- Elixir modules **must map 1:1** with their corresponding Gleam modules.
- Examples: 
  - `src/yog.gleam` -> `lib/yog.ex` (`Yog`)
  - `src/yog/model.gleam` -> `lib/yog/model.ex` (`Yog.Model`)
  - `src/yog/builder/labeled.gleam` -> `lib/yog/builder/labeled.ex` (`Yog.Builder.Labeled`)

## 2. Function Parity & Naming Conventions
- Aim to expose the full public API of the underlying Gleam module.
- Functions that simply pass through can use `defdelegate foo(x), to: :yog@module`.
- **Predicates**: Any Gleam boolean function named like `is_foo` or `has_bar` should be renamed in Elixir to be idiomatic: `foo?` or `has_bar?` (e.g. `is_directed` -> `directed?`).

## 3. Data Structure interop
- **Results**: Gleam's `Result(a, b)` maps to Elixir's `{:ok, a} | {:error, b}`.
- **Options**: Gleam's `Option(a)` maps natively to `{:some, a} | :none` on the Erlang VM. Handle these appropriately if returning them to the Elixir user, or document them clearly.
- **Custom Types**: Gleam custom types compile to tagged tuples. For example, `MyType(a)` in Gleam will be `{:my_type, a}` in Elixir.
- **Lists / Strings**: Gleam lists are Erlang lists. Gleam strings are UTF-8 binaries (same as Elixir `String.t()`). 

## 4. Documentation
- Provide full `@moduledoc` and `@doc` coverage.
- **Parity**: You should try to closely replicate the informational bounds of the Gleam documentation for the respective module/function.
- **Doctests**: While the informational docs should match Gleam, the code examples *must* be translated into idiomatic Elixir `iex>` doctests that pass ExUnit.

## 5. Code Quality & Credo Compliance
We use `Credo` for static analysis. You must write code that pleases Credo:
- **Empty List Checks**: Never use `length(list) == 0` or `length(list) > 0`. Instead, use `list == []`, `list != []`, or pattern matching.
- **Control Flow**: Avoid deep nesting. Prefer `with` blocks for chaining structural matching, or use multiple function clauses (`def foo(...) do`) over deeply nested `case` or `if/else` statements.
- **Pipe Chains**: Use the pipeline operator `|>` when chaining function calls idiomatcally.
- **Formatting**: Code must pass `mix format`.

## 6. Testing
- Every `lib/yog/foo.ex` file should have a corresponding `test/yog_foo_test.exs` file.
- Translating tests from Gleam ensures parity in logic. Make sure to test Elixir-specific wrapping behavior.
