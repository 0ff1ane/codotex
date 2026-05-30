defmodule Codotex.Llmtp do
  require Logger
  alias Codotex.Tools

  @timeout 50_000
  @model "google/gemini-2.5-flash"
  @openrouter_url "https://openrouter.ai/api/v1/chat/completions"

  def call(history) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer " <> System.get_env("OPENROUTER_API_KEY", "")}
    ]

    payload =
      JSON.encode!(%{
        model: @model,
        usage: %{include: false},
        tools: Tools.descriptions(),
        messages: history
      })

    case HTTPoison.post(@openrouter_url, payload, headers,
           timeout: @timeout,
           recv_timeout: @timeout
         ) do
      {:ok, %{body: body, status_code: 200}} ->
        extract_message(body)

      response ->
        Logger.error("LLM provider response error: #{inspect(response)}")
        {:error, "Unable to call LLM Provider endpoint"}
    end
  end

  defp extract_message(body) do
    body
    |> JSON.decode!()
    |> Map.get("choices")
    |> Enum.at(0)
    |> case do
      %{"finish_reason" => "stop", "message" => message} ->
        # text response
        {:ok, message}

      %{"finish_reason" => "tool_calls", "message" => message} ->
        # tool_calls response
        {:ok, message}

      other ->
        Logger.error("Unknown response from LLM provider: #{inspect(other)}")
        {:error, "unknown response"}
    end
  rescue
    err ->
      Logger.error("Error decoding Llmtp.call() body: #{inspect(err)}")
      {:error, "Unable to decode response in Llmtp.call()"}
  end
end
