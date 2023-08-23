# https://www.youtube.com/watch?v=xNzoerDljjo
# combinator returns a parser
# gives us a combinational expressivity

# todo
# - two-pass: add lexer that extracts tokens and feeds further
# - improve errors
# - add look-ahead to avoide choice() problem.

defmodule SqlParser do
  def run(input), do: parse(input)

  def run do
    "select col1 from (
      select col2, col3 from (
        select col4, col5, col6 from some_table
        )
      )
    "
    |> parse()
  end

  defp parse(input) do
    # compile time - assembling the lambda parser
    parser = select_statement()
    # runtime - invoking the parsers on input
    parser.(input)
  end

  defp select_statement() do
    sequence([
      keyword(:select),
      columns(),
      keyword(:from),
      choice([token(identifier()), subquery()])
    ])
    |> map(fn [_select, columns, _from, table] ->
      %{
        statement: :select,
        columns: columns,
        from: table
      }
    end)
  end

  defp subquery() do
    sequence([
      # wow
      token(char(?()),
      # deferring creation of another level
      lazy(fn -> select_statement() end),
      # to runtime when we actually need it
      token(char(?)))
    ])
    |> map(fn [_, stmt, _] -> stmt end)
  end

  # lazy combinator
  defp lazy(combinator) do
    fn input ->
      combinator.().(input)
    end
  end

  defp keyword(expected) do
    identifier()
    |> token()
    |> satisfy(fn token -> String.upcase(token) == String.upcase(to_string(expected)) end)
    |> map(fn _ -> expected end)
    |> error(fn _error -> "expected #{inspect(expected)}" end)
  end

  defp error(parser, fun) do
    fn input ->
      with {:error, reason} <- parser.(input),
           do: fun.(reason)
    end
  end

  defp columns(), do: separated_list(token(identifier()), token(char(?,)))

  defp token(parser) do
    # what is a token?
    # it is a sequence of identifiers (letters numbers and _) separated by
    # leading/trailiang whitespace (and) newlines
    sequence([
      # _lw leading whitespace
      many(choice([char(?\s), char(?\n)])),
      parser,
      # _tw trailing whitespace
      many(choice([char(?\s), char(?\n)]))
    ])
    |> map(fn [_lw, term, _tw] -> term end)
  end

  defp separated_list(element_parser, separator_parser) do
    #  what is a separated_list?
    # it is a sequence that starts with the first element
    # and followrd by zero or more tokens separated by a , and 0 or more ws
    sequence([
      # many(choice())
      element_parser,
      # ["col1", [[",", "col2"], [",", "col3"]]]
      many(sequence([separator_parser, element_parser]))
      #   input = " col1,

      #  col2,col3   col4"
      # {:ok, ["col1", [[44, "col2"], [44, "col3"]]], "col4"}
    ])
    # |> map(fn [head|rest] ->
    #     [head| Enum.map(Enum.at(rest,0), fn [_comma, token] ->  token end)]
    #   end)
    |> map(fn [head, rest] ->
      other_elements = Enum.map(rest, fn [_, token] -> token end)
      [head | other_elements]
    end)
  end

  # AND combinator
  # matches exact sequence
  defp sequence(parsers) do
    fn input ->
      case parsers do
        [] ->
          {:ok, [], input}

        [first | others] ->
          # AND implementation via WITH
          with {:ok, term, rest} <- first.(input),
               {:ok, other_terms, rest} <- sequence(others).(rest),
               do: {:ok, [term | other_terms], rest}
      end
    end
  end

  defp map(parser, mapper) do
    fn input ->
      with {:ok, term, rest} <- parser.(input),
           do: {:ok, mapper.(term), rest}
    end
  end

  # pretty expressive and intention revealing
  defp identifier() do
    many(identifier_char())
    |> satisfy(fn chars -> chars !== [] end)
    |> map(fn chars -> to_string(chars) end)
  end

  defp many(parser) do
    fn input ->
      case parser.(input) do
        {:error, _reason} ->
          {:ok, [], input}

        {:ok, first_term, rest} ->
          {:ok, other_terms, rest} = many(parser).(rest)
          {:ok, [first_term | other_terms], rest}
      end
    end
  end

  defp identifier_char(), do: choice([ascii_letter(), char(?_), digit()])
  defp ascii_letter(), do: satisfy(char(), fn char -> char in ?A..?Z or char in ?a..?z end)
  defp char(expected), do: satisfy(char(), fn char -> char == expected end)
  defp digit(), do: satisfy(char(), fn char -> char in ?0..?9 end)

  # general purpose combinator
  # OR combinator - need at least one parser to succeed <- implented via with block
  defp choice(parsers) do
    fn input ->
      case parsers do
        [] ->
          {:error, "no parser succeeded"}

        [first | others] ->
          # iff (if and only if) it fails
          # with returns anything that does NOT match its condition
          # when condition is matched, we enter do end block
          with {:error, _reason} <- first.(input),
               # we will try other parsers ON THAT SAME INPUT
               do: choice(others).(input)
      end
    end
  end

  # general purpose combinator
  # refines acceptanse of the parse result
  defp satisfy(parser, acceptor) do
    fn input ->
      with {:ok, term, rest} <- parser.(input) do
        if acceptor.(term),
          do: {:ok, term, rest},
          else: {:error, "term rejected"}
      end
    end
  end

  # this is a combinator, becase it returns a parser
  # we could write it in char(input) blabla for, in
  # which case that would not be a combinator
  # because it wouldn't return a parser 😁
  defp char() do
    fn input ->
      case input do
        "" -> {:error, "cannot parse empty string"}
        <<char::utf8, rest::binary>> -> {:ok, char, rest}
      end
    end
  end
end
