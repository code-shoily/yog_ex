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
      case e do
        %ErlangError{original: {:fatal, {{:error, {:wfc_Legal_Character, _}}, _, _, _}}} ->
          {:error, :bad_character}

        _ ->
          {:error, Exception.message(e)}
      end
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
    {0x2013, "-"},
    {0x2014, "-"},
    {0x201C, "\""},
    {0x201D, "\""},
    {0x2018, "'"},
    {0x2019, "'"},
    {0x201E, "\""},
    {0x201A, "'"},
    {0x00A0, " "},
    {0x202F, " "},
    {0x2026, "..."},
    {0x00AB, "<<"},
    {0x00BB, ">>"},
    {0x2022, "*"},
    {0x00B7, "*"}
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
