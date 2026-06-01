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
