defmodule Codotex do
  use GenServer

  require Logger

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
  def pending_tool_calls, do: GenServer.call(__MODULE__, :pending_tool_calls)
  # TODO - compact should end at assistant-messages.
  # Makes no sense to compact at a cut-off of user message without the assistants' response?
  def compact, do: GenServer.call(__MODULE__, :compact, @timeout)
  def approve, do: GenServer.call(__MODULE__, :approve, @timeout)
  def generate_agent_md, do: GenServer.call(__MODULE__, :generate_agent_md, @timeout)

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

  def handle_call(:generate_agent_md, _from, state) do
    if File.exists?("AGENT.md") do
      Logger.info("AGENT.md already exists, skipping dynamic generation.")
      :ok
    else
      Logger.info("AGENT.md not found. Dynamically generating content...")

      prompt = Codotex.Prompts.project_context()
      new_history = (state.history || []) ++ [%{"role" => "user", "content" => prompt}]

      make_new_agent_md(new_history)
      |> case do
        :ok ->
          Logger.info("AGENT.md successfully generated with LLM content.")
          {:reply, :done, %{state | history: new_history}}

        err ->
          Logger.error("Failed to write AGENT.md: #{inspect(err)}")
          {:reply, err, state}
      end
    end
  end

  defp initial_state(opts) do
    initial_prompt = Codotex.Prompts.main()

    %{
      opts: opts,
      history: [%{"role" => "system", "content" => initial_prompt}],
      pending_tool_calls: []
    }
  end

  defp compact_prompt(messages_to_compact) do
    Codotex.Prompts.compact() <>
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

  defp make_new_agent_md(context) do
    case Codotex.Llmtp.call(context) do
      {:ok, %{"content" => generated_content}} when is_binary(generated_content) ->
        File.write("AGENT.md", generated_content)

      {:ok, _other_response} ->
        Logger.warning(
          "LLM responded with tool calls or unexpected format for AGENT.md generation."
        )

        :error

      {:error, reason} ->
        Logger.error("Failed to get LLM response for AGENT.md generation: #{inspect(reason)}")
        :error
    end
  end
end
