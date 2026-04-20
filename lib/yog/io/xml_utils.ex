defmodule Yog.IO.XMLUtils do
  @moduledoc false

  @doc """
  Escapes special XML characters in a string.
  """
  def escape_xml(value) do
    str = to_string(value)

    if String.contains?(str, ["&", "<", ">", "\"", "'"]) do
      String.replace(str, ~r/[&<>"']/, fn
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
  Attempts to parse XML using xmerl.
  """
  def try_parse_xml(xml) do
    xml_charlist = String.to_charlist(xml)
    {doc, _} = :xmerl_scan.string(xml_charlist, quiet: true, space: :normalize)
    {:ok, doc}
  rescue
    e ->
      {:error, Exception.message(e)}
  catch
    :exit, {:fatal, {{:error, {:wfc_Legal_Character, _}}, _, _, _}} ->
      {:error, :bad_character}

    :exit, reason ->
      {:error, inspect(reason)}
  end

  @doc """
  Sanitizes XML string by replacing smart characters and removing invalid characters.
  """
  def sanitize_xml(xml) do
    xml
    |> replace_smart_characters()
    |> remove_invalid_xml_chars()
  end

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

  defp replace_smart_characters(xml) do
    Enum.reduce(@char_replacements, xml, fn {codepoint, replacement}, acc ->
      String.replace(acc, <<codepoint::utf8>>, replacement)
    end)
  end

  defp remove_invalid_xml_chars(xml) do
    xml
    |> String.to_charlist()
    |> Enum.filter(fn cp ->
      case cp do
        0x09 -> true
        0x0A -> true
        0x0D -> true
        _ when cp >= 0x20 and cp <= 0xD7FF -> true
        _ when cp >= 0xE000 and cp <= 0xFFFD -> true
        _ -> false
      end
    end)
    |> List.to_string()
  end
end
