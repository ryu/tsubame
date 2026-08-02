require "test_helper"

class MagicLinkTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "generate_for returns the raw token and stores only its digest" do
    token = MagicLink.generate_for(@user)
    magic_link = @user.magic_links.sole

    assert_equal Digest::SHA256.hexdigest(token), magic_link.token_digest
  end

  test "generate_for expires the link in 15 minutes" do
    freeze_time do
      MagicLink.generate_for(@user)
      assert_equal 15.minutes.from_now, @user.magic_links.sole.expires_at
    end
  end

  test "generate_for deletes the user's expired links but keeps valid ones" do
    expired = create_link(expires_at: 1.second.ago)
    still_valid = create_link(expires_at: 1.minute.from_now)

    MagicLink.generate_for(@user)

    assert_not MagicLink.exists?(expired.id)
    assert MagicLink.exists?(still_valid.id)
  end

  test "generate_for leaves other users' expired links alone" do
    other = create_link(user: users(:two), expires_at: 1.second.ago)

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

  test "find_by_token returns nil for an unknown token" do
    MagicLink.generate_for(@user)
    assert_nil MagicLink.find_by_token("nonexistent")
  end

  # Range 記法は始端を排他にできないため valid は >= になる。expired 側を排他にして重複を防ぐ。
  test "valid includes a link expiring exactly now, expired excludes it" do
    freeze_time do
      boundary = create_link(expires_at: Time.current)

      assert_includes MagicLink.valid, boundary
      assert_not_includes MagicLink.expired, boundary
    end
  end

  private
    def create_link(expires_at:, user: @user)
      user.magic_links.create!(token_digest: Digest::SHA256.hexdigest(SecureRandom.hex), expires_at: expires_at)
    end
end
