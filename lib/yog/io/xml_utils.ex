defmodule Yog.IO.XMLUtils do
  @moduledoc false

  @xml_escape_regex ~r/[&<>"']/

  @char_replacements [
    # Dashes
    {0x2013, "-"},
    {0x2014, "-"},
    # Quotes
    {0x201C, "\""},
    {0x201D, "\""},
    {0x2018, "'"},
    {0x2019, "'"},
    {0x201E, "\""},
    {0x201A, "'"},
    # Spaces
    {0x00A0, " "},
    {0x202F, " "},
    # Other common characters
    {0x2026, "..."},
    {0x00AB, "<<"},
    {0x00BB, ">>"},
    {0x2022, "*"},
    {0x00B7, "*"},
    # Accented uppercase letters
    {0x00C0, "A"},
    {0x00C1, "A"},
    {0x00C2, "A"},
    {0x00C3, "A"},
    {0x00C4, "A"},
    {0x00C5, "A"},
    {0x00C6, "AE"},
    {0x00C7, "C"},
    {0x00C8, "E"},
    {0x00C9, "E"},
    {0x00CA, "E"},
    {0x00CB, "E"},
    {0x00CC, "I"},
    {0x00CD, "I"},
    {0x00CE, "I"},
    {0x00CF, "I"},
    {0x00D0, "D"},
    {0x00D1, "N"},
    {0x00D2, "O"},
    {0x00D3, "O"},
    {0x00D4, "O"},
    {0x00D5, "O"},
    {0x00D6, "O"},
    {0x00D8, "O"},
    {0x00D9, "U"},
    {0x00DA, "U"},
    {0x00DB, "U"},
    {0x00DC, "U"},
    {0x00DD, "Y"},
    {0x00DF, "ss"},
    # Accented lowercase letters
    {0x00E0, "a"},
    {0x00E1, "a"},
    {0x00E2, "a"},
    {0x00E3, "a"},
    {0x00E4, "a"},
    {0x00E5, "a"},
    {0x00E6, "ae"},
    {0x00E7, "c"},
    {0x00E8, "e"},
    {0x00E9, "e"},
    {0x00EA, "e"},
    {0x00EB, "e"},
    {0x00EC, "i"},
    {0x00ED, "i"},
    {0x00EE, "i"},
    {0x00EF, "i"},
    {0x00F0, "d"},
    {0x00F1, "n"},
    {0x00F2, "o"},
    {0x00F3, "o"},
    {0x00F4, "o"},
    {0x00F5, "o"},
    {0x00F6, "o"},
    {0x00F8, "o"},
    {0x00F9, "u"},
    {0x00FA, "u"},
    {0x00FB, "u"},
    {0x00FC, "u"},
    {0x00FD, "y"},
    {0x00FF, "y"}
  ]

  @char_replacements_map Map.new(@char_replacements)

  @doc """
  Escapes special XML characters (`&`, `<`, `>`, `"`, `'`) in a string or value.

  Converts non-binary values to strings using `Yog.Utils.safe_string/1` before escaping.

  Time complexity: $O(N)$ where $N$ is the length of the string.

  ## Examples

      iex> Yog.IO.XMLUtils.escape_xml("<foo>")
      "&lt;foo&gt;"

      iex> Yog.IO.XMLUtils.escape_xml("a & b")
      "a &amp; b"

      iex> Yog.IO.XMLUtils.escape_xml(123)
      "123"
  """
  @spec escape_xml(any()) :: String.t()
  def escape_xml(value) do
    str = Yog.Utils.safe_string(value)

    if String.contains?(str, ["&", "<", ">", "\"", "'"]) do
      String.replace(str, @xml_escape_regex, fn
        "&" -> "&amp;"
        "<" -> "&lt;"
        ">" -> "&gt;"
        "\"" -> "&quot;"
        "'" -> "&apos;"
      end)
    else
      str
    end
  end

  @doc """
  Attempts to parse an XML binary string using Erlang's `:xmerl_scan`.

  Returns `{:ok, doc}` on success, `{:error, :bad_character}` if the XML contains
  unsupported or illegal XML control characters, or `{:error, reason}` for other parse failures.

  Raises `ArgumentError` if `xml` is not a binary string.

  Time complexity: $O(N)$ where $N$ is the length of the string.

  ## Examples

      iex> {:ok, doc} = Yog.IO.XMLUtils.try_parse_xml("<?xml version=\\"1.0\\"?><root/>")
      iex> is_tuple(doc)
      true

      iex> Yog.IO.XMLUtils.try_parse_xml("<unclosed>")
      {:error, "{:fatal, {:unexpected_end, {:file, :file_name_unknown}, {:line, 1}, {:col, 11}}}"}
  """
  @spec try_parse_xml(String.t()) :: {:ok, tuple()} | {:error, :bad_character | String.t()}
  def try_parse_xml(xml) when is_binary(xml) do
    xml_charlist = String.to_charlist(xml)
    {doc, _} = :xmerl_scan.string(xml_charlist, quiet: true, space: :normalize)
    {:ok, doc}
  rescue
    e ->
      {:error, Exception.message(e)}
  catch
    :exit, {:fatal, {{:error, {:wfc_Legal_Character, _}}, _, _, _}} ->
      {:error, :bad_character}

    :exit, {:fatal, {{:unexpected_char, _}, _, _, _}} ->
      {:error, :bad_character}

    :exit, reason ->
      {:error, inspect(reason)}
  end

  def try_parse_xml(xml) do
    raise ArgumentError, "expected xml to be a binary string, got: #{inspect(xml)}"
  end

  @doc """
  Sanitizes an XML string by replacing smart characters (smart quotes, dashes, non-breaking spaces,
  accented characters) with ASCII equivalents and removing invalid XML 1.0 control characters.

  Raises `ArgumentError` if `xml` is not a binary string.

  Time complexity: $O(N)$ single pass where $N$ is the length of the string.

  ## Examples

      iex> Yog.IO.XMLUtils.sanitize_xml("<root>hello \\u201Cworld\\u201D</root>")
      "<root>hello \\"world\\"</root>"

      iex> Yog.IO.XMLUtils.sanitize_xml("<root>hello\\bworld</root>")
      "<root>helloworld</root>"
  """
  @spec sanitize_xml(String.t()) :: String.t()
  def sanitize_xml(xml) when is_binary(xml) do
    xml
    |> String.to_charlist()
    |> sanitize_charlist([])
    |> IO.iodata_to_binary()
  rescue
    _ ->
      reraise ArgumentError,
              "expected valid UTF-8 binary string, got: #{inspect(xml)}",
              __STACKTRACE__
  end

  def sanitize_xml(xml) do
    raise ArgumentError, "expected xml to be a binary string, got: #{inspect(xml)}"
  end

  defp sanitize_charlist([], acc), do: Enum.reverse(acc)

  defp sanitize_charlist([cp | rest], acc) do
    case Map.fetch(@char_replacements_map, cp) do
      {:ok, replacement} ->
        sanitize_charlist(rest, [replacement | acc])

      :error ->
        if valid_xml_char?(cp) do
          sanitize_charlist(rest, [<<cp::utf8>> | acc])
        else
          sanitize_charlist(rest, acc)
        end
    end
  end

  defp valid_xml_char?(0x09), do: true
  defp valid_xml_char?(0x0A), do: true
  defp valid_xml_char?(0x0D), do: true
  defp valid_xml_char?(cp) when cp >= 0x20 and cp <= 0xD7FF, do: true
  defp valid_xml_char?(cp) when cp >= 0xE000 and cp <= 0xFFFD, do: true
  defp valid_xml_char?(_), do: false
end
