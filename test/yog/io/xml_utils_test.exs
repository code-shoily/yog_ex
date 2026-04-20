defmodule Yog.IO.XMLUtilsTest do
  use ExUnit.Case, async: true
  alias Yog.IO.XMLUtils

  test "escape_xml escapes special characters" do
    assert XMLUtils.escape_xml("<foo>") == "&lt;foo&gt;"
    assert XMLUtils.escape_xml("&") == "&amp;"
    assert XMLUtils.escape_xml("\"") == "&quot;"
    assert XMLUtils.escape_xml("'") == "&apos;"
    assert XMLUtils.escape_xml("a < b & c > d") == "a &lt; b &amp; c &gt; d"
  end

  test "escape_xml leaves normal text unchanged" do
    assert XMLUtils.escape_xml("hello world") == "hello world"
    assert XMLUtils.escape_xml("123") == "123"
    assert XMLUtils.escape_xml("") == ""
  end

  test "try_parse_xml with valid xml" do
    xml = "<?xml version=\"1.0\"?><root><child/></root>"
    assert {:ok, doc} = XMLUtils.try_parse_xml(xml)
    assert is_tuple(doc)
  end

  test "try_parse_xml with invalid characters returns bad_character" do
    # \b (backspace) is invalid in XML 1.0
    xml = "<?xml version=\"1.0\"?><root>hello\bworld</root>"
    assert {:error, :bad_character} = XMLUtils.try_parse_xml(xml)
  end

  test "try_parse_xml with malformed xml returns error" do
    assert {:error, _} = XMLUtils.try_parse_xml("not xml at all")
    assert {:error, _} = XMLUtils.try_parse_xml("<?xml version=\"1.0\"?><unclosed>")
  end

  test "sanitize_xml removes invalid control characters" do
    xml = "<?xml version=\"1.0\"?><root>hello\bworld</root>"
    sanitized = XMLUtils.sanitize_xml(xml)
    refute sanitized =~ "\b"
    assert sanitized =~ "helloworld"
  end

  test "sanitize_xml replaces smart quotes with ascii equivalents" do
    xml = "<root>hello \u201Cworld\u201D \u2018test\u2019</root>"
    sanitized = XMLUtils.sanitize_xml(xml)
    assert sanitized =~ ~s(hello "world" 'test')
    refute sanitized =~ <<0x201C::utf8>>
  end

  test "sanitize_xml replaces en-dash and em-dash" do
    xml = "<root>hello \u2013 world \u2014 test</root>"
    sanitized = XMLUtils.sanitize_xml(xml)
    assert sanitized =~ "hello - world - test"
  end

  test "sanitize_xml replaces accented characters" do
    xml = "<root>caf\u00E9 r\u00E9sum\u00E9 na\u00EFve</root>"
    sanitized = XMLUtils.sanitize_xml(xml)
    assert sanitized =~ "cafe resume naive"
    refute sanitized =~ <<0x00E9::utf8>>
  end

  test "sanitize_xml replaces ellipsis" do
    xml = "<root>hello\u2026</root>"
    sanitized = XMLUtils.sanitize_xml(xml)
    assert sanitized =~ "hello..."
  end

  test "sanitize_xml handles nbsp and narrow nbsp" do
    xml = "<root>hello\u00A0world\u202Ftest</root>"
    sanitized = XMLUtils.sanitize_xml(xml)
    assert sanitized =~ "hello world test"
  end

  test "sanitize_xml allows valid xml characters" do
    xml = "<root>hello\tworld\n test \r foo</root>"
    sanitized = XMLUtils.sanitize_xml(xml)
    assert sanitized =~ "\t"
    assert sanitized =~ "\n"
    assert sanitized =~ "\r"
  end

  test "sanitize_xml with clean xml returns similar content" do
    xml = "<?xml version=\"1.0\"?><root><child/></root>"
    sanitized = XMLUtils.sanitize_xml(xml)
    assert sanitized =~ "<root><child/></root>"
  end
end
