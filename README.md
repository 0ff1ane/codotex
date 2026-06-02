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
iex> Codotex.generate_agent_md()
```

## Some samples

# (Meta-?)prompting to add a function to create project context(AGENT.md)
```elixir
iex> "start genserver"
iex> GenServer.start_link(Codotex, [], name: Codotex)

iex> "clear old history"
iex> Codotex.reset
iex> Codotex.ask("check lib/codotex/prompts.ex and use the project_context prompt in a function in lib/codotex.ex to dynamically generate the AGENT.md file.")

iex> "it asked 2 questions"
iex> Codotex.ask("1. I want a summary of the project details in this folder in a useful and succint manner.\n2. Lets call the function `init`")
iex> "LLM responded with tool_calls"
iex> Codotex.approve()

iex> "!! it created a function with static string to write into AGENT.md :facepalm:"
iex> Codotex.ask("No, I want you to generate a function that will use Codotex.Llmtp.call and the prompt from Codotex.Prompts.project_context to dynamically generate the AGENT.md")

iex> Codotex.ask("Ok, lets do it")
iex> "LLM responded with tool_calls"
iex> Codotex.approve()

iex> "Recompile the module"
iex> recompile

iex> "!!we now have to function to generate AGENT.md file!!"
iex> Codotex.generate_agent_md()
```
