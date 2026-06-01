defmodule Codotex do
  use GenServer

  require Logger

  @prompt """
  You are a helpful coding assistant written in Elixir.
  You can write code, run tests, and help with debugging.
  Use the tools provided to help you with your tasks.
  """

  @compact_prompt """
  Summarize our conversation so far, focus on the key decisions made and the most important pieces of information to retain.
  I'd like to condense the message history to keep the important bits to save context size.
  """

  # increase timeout for slow llm provider calls
  @timeout 120_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def ask(query) do
    GenServer.call(__MODULE__, {:ask, query}, @timeout)
  end

  def reset, do: GenServer.call(__MODULE__, :reset)
  def history, do: GenServer.call(__MODULE__, :history)
  # TODO - compact should end at assistant-messages.
  # Makes no sense to compact at a cut-off a user message without the assistants' response?
  def compact, do: GenServer.call(__MODULE__, :compact, @timeout)
  def approve, do: GenServer.call(__MODULE__, :approve, @timeout)
  def pending_tool_calls, do: GenServer.call(__MODULE__, :pending_tool_calls)

  def generate_agent_md_file() do
    agent_md_content = """
    # Project Context: AGENT.md

    This document provides a comprehensive overview of the project, serving as a guide for new contributors and a reference for existing team members.

    ## Purpose

    The primary purpose of this project is to create an Elixir-based coding assistant. This assistant should be able to:
    - Write code in various programming languages.
    - Run tests for the generated code.
    - Assist in debugging code by providing insights and suggestions.
    - Interact with the user through a conversational interface.

    ## Key Features

    - **Code Generation**: Generate code snippets or full solutions based on user prompts.
    - **Test Execution**: Run tests against the generated or provided code and report results.
    - **Debugging Assistance**: Analyze code and test failures to suggest potential fixes and improvements.
    - **Tool Integration**: Utilize external tools and APIs (like file system operations, shell commands) to perform tasks.
    - **Context Management**: Maintain a conversational history to understand the user's ongoing needs and project context.
    - **Extensible Toolset**: Easily incorporate new tools to expand the assistant's capabilities.

    ## Technical Stack

    - **Elixir**: The core programming language for the assistant's logic and concurrency.
    - **GenServer**: Used for managing the assistant's state and handling asynchronous operations.
    - **LLM Provider Integration**: Interface with Large Language Models (LLMs) (e.g., OpenAI, Google Gemini) for natural language understanding and generation.
    - **JSON**: For data serialization and communication with LLMs and tools.
    - **File System Operations**: For reading and writing code files.
    - **Shell Commands**: For executing tests and other system commands.

    ## Setup Instructions

    To set up and run the project locally, follow these steps:

    1.  **Clone the Repository**:
        ```bash
        git clone <repository_url>
        cd <project_directory>
        ```

    2.  **Install Dependencies**:
        ```bash
        mix deps.get
        ```

    3.  **Configure LLM Provider**:
        Ensure your `.env` or configuration files are set up with the necessary API keys and endpoints for your chosen LLM provider.

    4.  **Start the Application**:
        ```bash
        mix run --no-halt
        ```

    5.  **Interact with the Assistant**:
        You can interact with the assistant through the `iex` console:
        ```elixir
        iex -S mix
        ```
        Then, you can use functions like `Codotex.ask("What is a GenServer?")` to interact.

    ## Contributing

    We welcome contributions to this project! Please refer to the `CONTRIBUTING.md` file (if available) for guidelines on how to submit pull requests, report issues, and general development practices.
    """

    Codotex.Tools.write_file("AGENT.md", agent_md_content)
  end

  @impl true
  def init(opts) do
    {:ok, initial_state(opts)}
  end

  @impl true
  def handle_call(:history, _from, state) do
    {:reply, state.history, state}
  end

  def handle_call(:pending_tool_calls, _from, state) do
    {:reply, state.pending_tool_calls, state}
  end

  def handle_call(:reset, _from, state) do
    {:reply, :ok, initial_state(state.opts)}
  end

  def handle_call(:approve, _from, %{pending_tool_calls: []} = state) do
    Logger.info("No pending tool calls")
    {:reply, :no_pending, state}
  end

  def handle_call(:approve, _from, %{pending_tool_calls: [tool_call | rest]} = state) do
    history = state.history ++ [run_tool_call(tool_call)]

    case rest do
      [] ->
        # this was the last pending tool_call
        # call LLM Provider with messages, results and tools
        case Codotex.Llmtp.call(history) do
          {:ok, llm_response} ->
            new_state =
              process(llm_response, %{
                state
                | history: history ++ [llm_response],
                  pending_tool_calls: []
              })

            {:reply, :done, new_state}

          err ->
            {:reply, err, state}
        end

      _ ->
        print_pending_tool_calls(rest)
        {:reply, :done, %{state | history: history, pending_tool_calls: rest}}
    end
  end

  def handle_call({:ask, query}, _from, state) do
    history = state.history ++ [%{"role" => "user", "content" => query}]

    case Codotex.Llmtp.call(history) do
      {:ok, llm_response} ->
        new_state = process(llm_response, %{state | history: history ++ [llm_response]})
        {:reply, :done, new_state}

      other ->
        {:reply, other, state}
    end
  end

  @impl true
  def handle_call(:compact, _from, state) do
    new_state =
      if length(state.history) < 3 do
        Logger.info("## Not enough messages(< 3) to compact. Skipping compaction...")
        state
      else
        new_messages = Enum.take(state.history, -3)
        old_messages = Enum.take(state.history, length(state.history) - 3 - 1)
        compaction_messages = [%{"role" => "user", "content" => compact_prompt(old_messages)}]
        {:ok, compacted_response} = Codotex.Llmtp.call(compaction_messages)
        %{state | history: [compacted_response] ++ new_messages}
      end

    {:reply, :done, new_state}
  end

  defp initial_state(opts) do
    %{
      opts: opts,
      history: [%{"role" => "system", "content" => @prompt}],
      pending_tool_calls: []
    }
  end

  defp compact_prompt(messages_to_compact) do
    @compact_prompt <>
      """
      \n
      ## Conversation
      #{JSON.encode!(messages_to_compact)}
      """
  end

  defp process(llm_response, state) do
    case extract_llm_response(llm_response) do
      {:ok, :message, content} ->
        Logger.info("Assistant: #{content}")
        state

      {:ok, :tool_calls, tool_calls} ->
        print_pending_tool_calls(tool_calls)
        %{state | pending_tool_calls: tool_calls}

      {:error, reason} ->
        Logger.error("Unable to query LLM: #{inspect(reason)}")
        state
    end
  end

  defp print_pending_tool_calls([]), do: Logger.info("No pending tool calls")

  defp print_pending_tool_calls([tool_call | _]) do
    Logger.info(
      "Call Codotex.approve() to run #{tool_call["function"]["name"]}(#{inspect(tool_call["function"]["arguments"])})"
    )
  end

  defp run_tool_call(%{"id" => tc_id, "function" => %{"name" => name, "arguments" => args}}) do
    result = Codotex.Tools.call(name, JSON.decode!(args))

    %{role: "tool", tool_call_id: tc_id, content: JSON.encode!(result)}
  end

  defp run_tool_call(tool_call) do
    Logger.error("Unable to handle tool_call format: #{inspect(tool_call)}")
  end

  defp extract_llm_response(%{"tool_calls" => tool_calls}), do: {:ok, :tool_calls, tool_calls}
  defp extract_llm_response(%{"content" => content}), do: {:ok, :message, content}
  defp extract_llm_response(other), do: {:error, "Unknown response #{inspect(other)}"}
end
