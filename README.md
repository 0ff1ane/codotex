# Codotex

** Experimental self-modifying coding agent harness in Elixir

## Notes

A basic conding agent harness which can modify its behaviour without requiring restarts.
Written in Elixir, uses Openrouter with Gemini 3.5 flash.


Quite fascinating to use a coding agent which can modify itself during run-time.
Its advantage(beamVM, hot-reloading) also means it's difficult to distribute as an executable.


## Usage

**Note:** You need to set your Openrouter API key in the environment variable `OPENROUTER_API_KEY`.
**Note:** Every tool call needs to be approved by calling `Codotex.approve()`. To view the list of pending tool calls, use `Codotex.pending_tool_calls()`.

Start the process
```elixir
iex> GenServer.start_link(Codotex, [], name: Codotex)
```

Ask a question
```elixir
iex> Codotex.ask("what files are in lib/ and what do they do?")
```

List available tools
```elixir
iex> Codotex.tools()
```

View message history
```elixir
iex> Codotex.history()
```

Compact older messages
```elixir
iex> Codotex.compact()
```

Add project context(AGENT.md)
```elixir
iex> Codotex.init()
```

## Some samples

# (Meta-?)prompting to add a function to create project context(AGENT.md)
```elixir
iex> Codotex.ask("what would be a good prompt to ask you to generate an AGENT.md file to generate project context?")
iex> Codotex.ask("use this prompt in a function in lib/codotex.ex to generate the AGENT.md file. check the tools used in lib/codotex/tools.ex")
iex> Codotex.approve()
iex> Codotex.approve()
iex> Codotex.approve()
iex> recompile
iex> "we now have to function to generate AGENT.md file!!"
iex> Codotex.generate_agent_md_file()
```
