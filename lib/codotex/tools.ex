defmodule Codotex.Tools do
  require Logger

  def descriptions() do
    [
      list_files_tool(),
      read_file_tool(),
      write_file_tool(),
      shell_tool()
    ]
  end

  defp trunc_long_string(string) do
    if String.length(string) > 100 do
      String.slice(string, 0, 100) <> "..."
    else
      string
    end
  end

  def call(func_name, func_args) do
    Logger.info("Calling: #{func_name}(#{trunc_long_string(inspect(func_args))})")

    result =
      case func_name do
        "list_files" ->
          list_files(func_args["path"])

        "read_file" ->
          read_file(
            func_args["path"],
            func_args["start_line"] || 0,
            func_args["end_line"] || nil
          )

        "write_file" ->
          write_file(
            func_args["path"],
            func_args["new_string"],
            func_args["start_line"] || 0,
            func_args["end_line"] || nil
          )

        "shell" ->
          shell(func_args["command"])

        _ ->
          :function_not_found
      end

    Logger.info("Result: #{trunc_long_string(inspect(result))}")
    result
  end

  defp list_files_tool() do
    %{
      type: "function",
      function: %{
        name: "list_files",
        description: "lists files in the given path",
        parameters: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description: "Path to list files"
            }
          },
          required: ["path"]
        }
      }
    }
  end

  defp read_file_tool() do
    %{
      type: "function",
      function: %{
        name: "read_file",
        description: "reads the file at path with optional start and end offsets",
        parameters: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description: "Path to the file"
            },
            start_line: %{
              type: "integer",
              description: "The line number to start from. Optional"
            },
            end_line: %{
              type: "integer",
              description: "The line number to end at. Optional"
            }
          },
          required: ["path"]
        }
      }
    }
  end

  defp write_file_tool() do
    %{
      type: "function",
      function: %{
        name: "write_file",
        description: "writes the file at path with optional start and end offsets",
        parameters: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description: "Path to the file"
            },
            new_string: %{
              type: "string",
              description: "Content of the file to write"
            },
            start_line: %{
              type: "integer",
              description: "The line number to start from. Optional"
            },
            end_line: %{
              type: "integer",
              description: "The line number to end at. Optional"
            }
          },
          required: ["path"]
        }
      }
    }
  end

  defp shell_tool() do
    %{
      type: "function",
      function: %{
        name: "shell",
        description: "Runs a shell command",
        parameters: %{
          type: "object",
          properties: %{
            command_string: %{
              type: "string",
              description: "The shell command to run"
            }
          },
          required: ["command_string"]
        }
      }
    }
  end

  def reject_ignored_paths(paths) do
    ignored = [
      ".git",
      ".gitignore",
      ".DS_Store",
      "_build",
      ".elixir_ls",
      ".formatter.exs",
      ".tool-versions",
      "mix.lock"
    ]

    paths
    |> Enum.reject(fn subpath ->
      Enum.any?(ignored, &String.starts_with?(subpath, &1))
    end)
  end

  defp list_files(path) do
    case File.stat(path) do
      {:ok, file} when file.type == :directory ->
        path
        |> File.ls!()
        |> reject_ignored_paths()

      {:ok, _} ->
        [path]

      _ ->
        []
    end
  end

  defp read_file_by_lines(path) do
    path |> File.read() |> elem(1) |> String.split("\n")
  end

  defp read_file(path, start_line \\ 0, end_line \\ nil) do
    file = read_file_by_lines(path)
    offset = (end_line || length(file)) - start_line

    file
    |> Enum.drop(start_line)
    |> Enum.take(offset)
    |> Enum.join("\n")
  end

  def write_file(path, new_string, start_line \\ 0, end_line \\ nil) do
    case File.exists?(path) do
      false -> File.write!(path, "")
      true -> :ok
    end

    file = read_file_by_lines(path)
    end_line = end_line || length(file)

    IO.inspect({start_line, end_line, path}, label: "write_file")

    file
    |> Enum.with_index()
    |> Enum.map(fn {line, idx} ->
      cond do
        idx == start_line -> new_string
        idx < start_line || idx > end_line -> line
        true -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
    |> then(fn result -> File.write!(path, result) end)
  end

  defp shell(command) do
    System.shell(command)
  end
end
