require "test_helper"

class Feed::OpmlTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @xml = file_fixture("sample.opml").read
  end

  test "imports UTF-8 content" do
    assert_difference "Feed.count", 3 do
      Feed.import_from_opml(@xml, user: @user)
    end
  end

  test "imports binary content as uploaded files provide it" do
    assert_difference "Feed.count", 3 do
      Feed.import_from_opml(@xml.dup.force_encoding(Encoding::BINARY), user: @user)
    end
  end

  test "strips the BOM from UTF-8 content" do
    assert_difference "Feed.count", 3 do
      Feed.import_from_opml(with_bom(@xml, Encoding::UTF_8), user: @user)
    end
  end

  test "strips the BOM from binary content" do
    assert_difference "Feed.count", 3 do
      Feed.import_from_opml(with_bom(@xml, Encoding::BINARY), user: @user)
    end
  end

  test "rejects content that is not XML" do
    error = assert_raises Feed::Opml::ImportError do
      Feed.import_from_opml("これはXMLではありません", user: @user)
    end

    assert_equal "XMLファイルを選択してください。", error.message
  end

  test "rejects invalid byte sequences without raising an encoding error" do
    assert_raises Feed::Opml::ImportError do
      Feed.import_from_opml("\xC3\x28".dup.force_encoding(Encoding::BINARY), user: @user)
    end
  end

  private
    def with_bom(xml, encoding) = "\xEF\xBB\xBF#{xml}".dup.force_encoding(encoding)
end
