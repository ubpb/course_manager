require "test_helper"

# What the participant list and its export say about how a participant
# registered.
class AdminOriginHelperTest < ActionView::TestCase

  test "origin_label names each origin" do
    assert_equal(["Konto", "Gast", "Admin", nil],
                 ["account", "guest", "admin", nil].map { origin_label(Registration.new(origin: it)) })
  end

  test "origin_hint gives the participant form an icon and a sentence for each origin" do
    assert_equal([["fa-user-check", "Mit Bibliothekskonto angemeldet"],
                  ["fa-user", "Als Gast angemeldet"],
                  ["fa-user-pen", "Im Admin eingetragen"],
                  nil],
                 ["account", "guest", "admin", nil].map { origin_hint(Registration.new(origin: it)) })
  end

end
