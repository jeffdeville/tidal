---
name: elixir-patterns
description: Idiomatic Elixir conventions for pattern matching, error handling, and function design. Use when writing or reviewing Elixir code in this project.
---

# Elixir Patterns

## Quick Start

When writing Elixir code, apply these patterns automatically:

```elixir
# Pattern match in function heads
def process({:ok, data}), do: handle_success(data)
def process({:error, reason}), do: handle_error(reason)

# Use `with` for sequential operations that might fail
with {:ok, user} <- fetch_user(id),
     {:ok, account} <- fetch_account(user.account_id),
     :ok <- validate_access(user, account) do
  {:ok, %{user: user, account: account}}
end
```

## Guidelines

- Prefer pattern matching in function heads over case statements
- Use tagged tuples: `{:ok, result} | {:error, reason}`
- Keep functions small (<20 lines ideal)
- Limit pipe chains to 4-5 steps maximum
- Limit `with` statements to 3-4 clauses
- Limit function arity to 3-4 parameters (use options keyword list for more)
- Avoid nested conditionals; refactor to separate functions

## Examples

### Pattern Matching Over Case

**Avoid**:

```elixir
def handle(event) do
  case event do
    {:user, action, data} -> handle_user(action, data)
    {:system, action, data} -> handle_system(action, data)
    _ -> {:error, :unknown_event}
  end
end
```

**Prefer**:

```elixir
def handle({:user, action, data}), do: handle_user(action, data)
def handle({:system, action, data}), do: handle_system(action, data)
def handle(_), do: {:error, :unknown_event}
```

### Error Handling with `with`

**Avoid**:

```elixir
def create_order(params) do
  case validate_params(params) do
    {:ok, validated} ->
      case create_record(validated) do
        {:ok, record} ->
          case notify_user(record) do
            :ok -> {:ok, record}
            error -> error
          end
        error -> error
      end
    error -> error
  end
end
```

**Prefer**:

```elixir
def create_order(params) do
  with {:ok, validated} <- validate_params(params),
       {:ok, record} <- create_record(validated),
       :ok <- notify_user(record) do
    {:ok, record}
  end
end
```

### Pipe Chains

**Avoid**:

```elixir
input
|> String.trim()
|> String.downcase()
|> String.split(",")
|> Enum.map(&String.trim/1)
|> Enum.reject(&(&1 == ""))
|> Enum.map(&parse_item/1)
|> Enum.filter(&valid?/1)
|> Enum.sort_by(& &1.priority)
```

**Prefer**:

```elixir
input
|> normalize_input()
|> parse_items()
|> sort_by_priority()

defp normalize_input(input) do
  input
  |> String.trim()
  |> String.downcase()
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))
end
```

## References

For more details, see:

- [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- [Credo](https://hexdocs.pm/credo/overview.html)
