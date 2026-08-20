defmodule Yog.IO.XMLUtilsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Yog.IO.XMLUtils

  doctest Yog.IO.XMLUtils

  describe "escape_xml/1" do
    test "escapes special characters" do
      assert XMLUtils.escape_xml("<foo>") == "&lt;foo&gt;"
      assert XMLUtils.escape_xml("&") == "&amp;"
      assert XMLUtils.escape_xml("\"") == "&quot;"
      assert XMLUtils.escape_xml("'") == "&apos;"
      assert XMLUtils.escape_xml("a < b & c > d") == "a &lt; b &amp; c &gt; d"
    end

    test "leaves normal text unchanged" do
      assert XMLUtils.escape_xml("hello world") == "hello world"
      assert XMLUtils.escape_xml("123") == "123"
      assert XMLUtils.escape_xml("") == ""
    end

    test "handles non-string inputs safely" do
      assert XMLUtils.escape_xml(:atom_key) == "atom_key"
      assert XMLUtils.escape_xml(100) == "100"
      assert XMLUtils.escape_xml(nil) == ""
    end
  end

  describe "try_parse_xml/1" do
    test "parses valid xml" do
      xml = "<?xml version=\"1.0\"?><root><child/></root>"
      assert {:ok, doc} = XMLUtils.try_parse_xml(xml)
      assert is_tuple(doc)
    end

    test "returns bad_character for invalid xml 1.0 control chars" do
      xml = "<?xml version=\"1.0\"?><root>hello\bworld</root>"
      assert {:error, :bad_character} = XMLUtils.try_parse_xml(xml)
    end

    test "returns error for malformed xml" do
      assert {:error, _} = XMLUtils.try_parse_xml("not xml at all")
      assert {:error, _} = XMLUtils.try_parse_xml("<?xml version=\"1.0\"?><unclosed>")
    end

    test "raises ArgumentError when input is not a binary" do
      assert_raise ArgumentError, ~r/expected xml to be a binary string/, fn ->
        XMLUtils.try_parse_xml(123)
      end

      assert_raise ArgumentError, ~r/expected xml to be a binary string/, fn ->
        XMLUtils.try_parse_xml(nil)
      end
    end
  end

  describe "sanitize_xml/1" do
    test "removes invalid control characters" do
      xml = "<?xml version=\"1.0\"?><root>hello\bworld</root>"
      sanitized = XMLUtils.sanitize_xml(xml)
      refute sanitized =~ "\b"
      assert sanitized =~ "helloworld"
    end

    test "replaces smart quotes with ascii equivalents" do
      xml = "<root>hello \u201Cworld\u201D \u2018test\u2019</root>"
      sanitized = XMLUtils.sanitize_xml(xml)
      assert sanitized =~ ~s(hello "world" 'test')
      refute sanitized =~ <<0x201C::utf8>>
    end

    test "replaces en-dash and em-dash" do
      xml = "<root>hello \u2013 world \u2014 test</root>"
      sanitized = XMLUtils.sanitize_xml(xml)
      assert sanitized =~ "hello - world - test"
    end

    test "replaces accented characters" do
      xml = "<root>caf\u00E9 r\u00E9sum\u00E9 na\u00EFve</root>"
      sanitized = XMLUtils.sanitize_xml(xml)
      assert sanitized =~ "cafe resume naive"
      refute sanitized =~ <<0x00E9::utf8>>
    end

    test "replaces ellipsis" do
      xml = "<root>hello\u2026</root>"
      sanitized = XMLUtils.sanitize_xml(xml)
      assert sanitized =~ "hello..."
    end

    test "handles nbsp and narrow nbsp" do
      xml = "<root>hello\u00A0world\u202Ftest</root>"
      sanitized = XMLUtils.sanitize_xml(xml)
      assert sanitized =~ "hello world test"
    end

    test "allows valid xml characters including whitespace control chars" do
      xml = "<root>hello\tworld\n test \r foo</root>"
      sanitized = XMLUtils.sanitize_xml(xml)
      assert sanitized =~ "\t"
      assert sanitized =~ "\n"
      assert sanitized =~ "\r"
    end

    test "with clean xml returns identical content" do
      xml = "<?xml version=\"1.0\"?><root><child/></root>"
      sanitized = XMLUtils.sanitize_xml(xml)
      assert sanitized == xml
    end

    test "raises ArgumentError when input is not a binary" do
      assert_raise ArgumentError, ~r/expected xml to be a binary string/, fn ->
        XMLUtils.sanitize_xml(123)
      end

      assert_raise ArgumentError, ~r/expected xml to be a binary string/, fn ->
        XMLUtils.sanitize_xml(nil)
      end
    end

    test "raises ArgumentError on invalid UTF-8 binary" do
      assert_raise ArgumentError, ~r/expected valid UTF-8 binary string/, fn ->
        XMLUtils.sanitize_xml(<<0xFF, 0xFF>>)
      end
    end
  end

  describe "property tests" do
    property "escape_xml produces string where special XML characters are escaped" do
      check all(str <- StreamData.string(:utf8)) do
        escaped = XMLUtils.escape_xml(str)

        if String.contains?(str, "<") do
          assert String.contains?(escaped, "&lt;")
        end

        if String.contains?(str, ">") do
          assert String.contains?(escaped, "&gt;")
        end

        if String.contains?(str, "&") do
          assert String.contains?(escaped, "&amp;")
        end
      end
    end

    property "sanitize_xml produces valid string without illegal XML control characters" do
      check all(str <- StreamData.string(:utf8)) do
        sanitized = XMLUtils.sanitize_xml(str)
        charlist = String.to_charlist(sanitized)

        for cp <- charlist do
          refute cp in 0x00..0x08
          refute cp in [0x0B, 0x0C]
          refute cp in 0x0E..0x1F
        end
      end
    end

    property "sanitizing invalid XML with control chars allows try_parse_xml to succeed" do
      check all(text <- StreamData.string(:ascii)) do
        escaped = XMLUtils.escape_xml(text)
        xml = "<?xml version=\"1.0\"?><root>" <> escaped <> "</root>"
        sanitized = XMLUtils.sanitize_xml(xml)

        assert {:ok, _doc} = XMLUtils.try_parse_xml(sanitized)
      end
    end
  end
end
