defmodule ParserTest do
  use ExUnit.Case
  doctest Parser

  test "single character" do
    assert Parser.run("a") == {:ok, 97, ""}
    assert Parser.run("Z") == {:ok, 90, ""}
    assert Parser.run("lol is this") == {:ok, 108, "ol is this"}
  end

  test "select foo from bar" do
    assert Parser.run("select foo from bar") == nil
  end
end
