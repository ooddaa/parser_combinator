# Saša's talk
# https://www.youtube.com/watch?v=xNzoerDljjo

defmodule Parser do
  def run(input), do: parse(input)

  defp parse(input) do
    # parser = choice([digit(), letter()])
    parser = choice([char()])
    parser.(input)
  end

  defp choice(parsers) do
    fn input ->
      case parsers do
        [] ->
          {:error, "no parser succeeded"}

        [parser | other_parsers] ->
          with {:error, reason} <- parser.(input),
               do: choice(other_parsers).(input)
      end
    end
  end

  defp digit, do: satisfy(char(), fn term -> term in ?0..?9 end)
  defp letter, do: satisfy(char(), fn term -> term in ?A..?Z or term in ?a..?z end)
  defp char(expected), do: satisfy(char(), fn term -> term == expected end)

  # combinator
  # combinator returs a parser
  defp satisfy(parser, predicate) do
    fn input ->
      with {:ok, term, rest} <- parser.(input) do
        if predicate.(term),
          do: {:ok, term, rest},
          else: {:error, "term is rejected: #{to_string(term)}"}
      end
    end
  end

  # combinator returs a parser
  # (input: string) :: {:error, reason } || {:ok, parse_term, rest}
  defp char() do
    fn input ->
      case input do
        "" -> {:error, "unexpected end of input"}
        <<char::utf8, rest::binary>> -> {:ok, char, rest}
      end
    end
  end
end
