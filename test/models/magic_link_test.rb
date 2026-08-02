require "test_helper"

class MagicLinkTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "generate_for does not store the raw token" do
    token = MagicLink.generate_for(@user)

    assert_not_equal token, @user.magic_links.sole.token_digest
  end

  test "generate_for expires the link in 15 minutes" do
    freeze_time do
      MagicLink.generate_for(@user)
      assert_equal 15.minutes.from_now, @user.magic_links.sole.expires_at
    end
  end

  # 再送のたびに生きたトークンが増えないよう、直前のリンクは有効でも捨てる。
  test "generate_for replaces the user's existing links" do
    previous = create_link(expires_at: 1.minute.from_now)

    MagicLink.generate_for(@user)

    assert_not MagicLink.exists?(previous.id)
    assert_equal 1, @user.magic_links.count
  end

  test "generate_for leaves other users' links alone" do
    other = create_link(user: users(:two), expires_at: 1.minute.from_now)

    MagicLink.generate_for(@user)

    assert MagicLink.exists?(other.id)
  end

  test "find_by_token returns the link for a valid token" do
    token = MagicLink.generate_for(@user)
    assert_equal @user.magic_links.sole, MagicLink.find_by_token(token)
  end

  test "find_by_token returns nil for an expired token" do
    token = MagicLink.generate_for(@user)

    travel 16.minutes do
      assert_nil MagicLink.find_by_token(token)
    end
  end

  test "find_by_token returns nil for a token that was never issued" do
    MagicLink.generate_for(@user)

    assert_nil MagicLink.find_by_token(SecureRandom.urlsafe_base64(32))
  end

  # Range 記法は始端を排他にできないため、期限ちょうどのリンクはまだ有効になる。
  test "valid includes a link expiring exactly now" do
    freeze_time do
      assert_includes MagicLink.valid, create_link(expires_at: Time.current)
    end
  end

  private
    def create_link(expires_at:, user: @user)
      user.magic_links.create!(token_digest: SecureRandom.hex(32), expires_at: expires_at)
    end
end
