defmodule CodotexTest do
  use ExUnit.Case
  doctest Codotex

  test "greets the world" do
    assert Codotex.hello() == :world
  end
end
