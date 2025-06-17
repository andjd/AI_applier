- Use Req for network requests.
- Use with to avoid nested case statements.  Proper with syntax with side-effect functions (e.g. IO.puts) looks like this:
```
with {:ok, foo} <- (IO.puts("Step 1: Doing foo..."); do_foo()),
  {:ok, bar} <- (IO.puts("Step 2: Doing bar..."); do_bar(foo)),
  {:ok, baz} <- (IO.puts("Step 3: Doing baz..."); do_baz(bar))
do
  IO.puts("All steps completed successfully!")
  {:ok, baz}
else
  {:error, reason} ->
    IO.puts("Error: #{reason}")
    {:error, reason}
end
```

Use the built-in JSON module instead of Jason lib for JSON parsing and encoding.
