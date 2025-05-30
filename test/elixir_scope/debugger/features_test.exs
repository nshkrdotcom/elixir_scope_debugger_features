defmodule ElixirScope.Debugger.FeaturesTest do
  use ExUnit.Case
  doctest ElixirScope.Debugger.Features

  test "greets the world" do
    assert ElixirScope.Debugger.Features.hello() == :world
  end
end
