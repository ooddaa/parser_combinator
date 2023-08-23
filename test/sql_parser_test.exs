defmodule SqlParserTest do
  use ExUnit.Case

  test "select foo from bar" do
    query = "select foo from bar"
    assert SqlParser.run(query) == {:ok, %{columns: ["foo"], from: "bar", statement: :select}, ""}
  end

  test "happy case" do
    query = "select col1 from (
      select col2, col3 from (
        select col4, col5, col6 from some_table
        )
      )
    "

    assert SqlParser.run(query) == {
             :ok,
             %{
               columns: ["col1"],
               from: %{
                 columns: ["col2", "col3"],
                 from: %{
                   columns: ["col4", "col5", "col6"],
                   from: "some_table",
                   statement: :select
                 },
                 statement: :select
               },
               statement: :select
             },
             ""
           }
  end
end
