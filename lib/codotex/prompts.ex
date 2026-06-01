defmodule Codotex.Prompts do
  defp load_project_context() do
    File.read("AGENT.md")
    |> case do
      {:ok, file} ->
        """
        ## Project context
        #{file}
        """

      _ ->
        ""
    end
  end

  def main() do
    """
    You are a helpful coding assistant written in Elixir.
    You can write code, run tests, and help with debugging.
    Use the tools provided to help you with your tasks.

    #{load_project_context()}

    """
  end

  def project_context() do
    """
    Please generate an `AGENT.md` file that outlines the project's context,
    including its purpose, key features, technical stack, and setup instructions.
    The purpose of this file is to provide a comprehensive overview for new contributors
    and to serve as a reference for existing team members.
    """
  end

  def compact() do
    """
    Summarize our conversation so far, focus on the key decisions made and the most important pieces of information to retain.
    I'd like to condense the message history to keep the important bits to save context size.
    """
  end
end
