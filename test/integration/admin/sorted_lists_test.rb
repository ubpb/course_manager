require "test_helper"

# Topics and target groups are short lists staff keep in an order of their
# own. Both work the same way: new entries open in place and join at the end,
# entries are dragged to a new position.
module Admin
  class SortedListsTest < ActionDispatch::IntegrationTest

    include AdminLogin

    LISTS = {
      "topic" => {model: Topic, list_id: "topics"},
      "target_group" => {model: TargetGroup, list_id: "target-groups"}
    }.freeze

    setup { log_in_admin }

    # The URL of a route helper named at runtime: route("admin_topics") is admin_topics_path.
    def route(helper, *)
      public_send(:"#{helper}_path", *)
    end

    LISTS.each do |name, list|
      model = list[:model]
      plural = name.pluralize

      test "#{plural}: the list shows the entries in their order" do
        model.create!(title: "B")
        model.create!(title: "A").move_to_top

        get route("admin_#{plural}")

        assert_response :success
        assert_select "ul##{list[:list_id]} li strong", count: 2
        assert_equal(["A", "B"], css_select("ul##{list[:list_id]} li strong").map { it.text.strip })
      end

      test "#{plural}: an empty list says so" do
        get route("admin_#{plural}")

        assert_select ".text-muted", text: /\AKeine \S+ vorhanden\z/
      end

      test "#{plural}: the form for a new entry opens in its frame" do
        get route("new_admin_#{name}"), headers: {"Turbo-Frame" => "new_#{name}"}

        assert_response :success
        assert_select "turbo-frame#new_#{name} form"
      end

      test "#{plural}: a new entry joins at the end" do
        model.create!(title: "Erstes")

        post route("admin_#{plural}"), params: {name => {title: "Neues"}}

        assert_redirected_to route("admin_#{plural}")
        assert_equal ["Erstes", "Neues"], model.order(:position).pluck(:title)
      end

      test "#{plural}: a new entry from the frame refreshes the page" do
        post route("admin_#{plural}"), params: {name => {title: "Neues"}},
                                       headers: {"Turbo-Frame" => "new_#{name}"}, as: :turbo_stream

        assert_response :success
        assert_select "turbo-stream[action=refresh]"
        assert model.exists?(title: "Neues")
      end

      test "#{plural}: a new entry needs a title of its own" do
        model.create!(title: "Vorhanden")

        post route("admin_#{plural}"), params: {name => {title: "Vorhanden"}}

        assert_response :unprocessable_content
        assert_equal 1, model.count
      end

      test "#{plural}: an entry is renamed in place" do
        entry = model.create!(title: "Alt")

        get route("edit_admin_#{name}", entry)

        assert_response :success

        patch route("admin_#{name}", entry), params: {name => {title: "Neu"}}

        assert_redirected_to route("admin_#{plural}")
        assert_equal "Neu", entry.reload.title
      end

      test "#{plural}: an entry keeps its title when the new one is blank" do
        entry = model.create!(title: "Alt")

        patch route("admin_#{name}", entry), params: {name => {title: ""}}

        assert_response :unprocessable_content
        assert_equal "Alt", entry.reload.title
      end

      test "#{plural}: removing an entry leads back to the list" do
        entry = model.create!(title: "Weg")

        delete route("admin_#{name}", entry)

        assert_redirected_to route("admin_#{plural}")
        assert_not model.exists?(entry.id)
      end

      test "#{plural}: removing an entry from the list refreshes it" do
        entry = model.create!(title: "Weg")

        delete route("admin_#{name}", entry), as: :turbo_stream

        assert_select "turbo-stream[action=refresh]"
        assert_not model.exists?(entry.id)
      end

      test "#{plural}: an entry moves to the position it is dropped at" do
        first, second, third = ["A", "B", "C"].map { model.create!(title: it) }

        patch route("reorder_admin_#{name}", third), params: {name => {position: 1}}

        assert_response :success
        assert_equal [third, first, second], model.order(:position).to_a
      end
    end

  end
end
