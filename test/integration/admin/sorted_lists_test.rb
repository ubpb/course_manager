require "test_helper"

# Topics and target groups are short lists staff keep in an order of their
# own. Both work the same way: new entries and renames open in a modal, new
# entries join at the end, entries are dragged to a new position.
module Admin
  class SortedListsTest < ActionDispatch::IntegrationTest

    include AdminLogin

    LISTS = {
      "topic" => {model: Topic, list_id: "topics"},
      "target_group" => {model: TargetGroup, list_id: "target-groups"}
    }.freeze

    # What Turbo sends for a link with data-turbo-stream.
    TURBO_STREAM_HEADERS = {
      "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
    }.freeze

    setup { log_in_admin }

    # The URL of a route helper named at runtime: route("admin_topics") is admin_topics_path.
    def route(helper, *)
      public_send(:"#{helper}_path", *)
    end

    LISTS.each do |name, list|
      model = list[:model]
      plural = name.pluralize
      modal_id = "#{name.dasherize}-modal"
      form_id = "#{name.dasherize}-form"

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

      test "#{plural}: the list opens new entries and renames in a modal" do
        entry = model.create!(title: "Vorhanden")

        get route("admin_#{plural}")

        assert_select "##{modal_id}"
        assert_select "a[href=?][data-turbo-stream]", route("new_admin_#{name}")
        assert_select "a[href=?][data-turbo-stream]", route("edit_admin_#{name}", entry)
      end

      test "#{plural}: the list keeps its scroll position when it refreshes" do
        get route("admin_#{plural}")

        assert_select "head meta[name=turbo-refresh-scroll][content=preserve]"
      end

      test "#{plural}: the form for a new entry opens in a modal" do
        get route("new_admin_#{name}"), headers: TURBO_STREAM_HEADERS

        assert_response :success
        assert_equal "text/vnd.turbo-stream.html", response.media_type
        assert_select "turbo-stream[action=replace][target=#{modal_id}]"
        assert_includes response.body, %(id="#{form_id}")
      end

      # Submitted through Turbo, the form would get the answers meant for the modal.
      test "#{plural}: the form for a new entry also opens as a page, submitted without Turbo" do
        get route("new_admin_#{name}")

        assert_response :success
        assert_select "form[action=?][data-turbo=false]", route("admin_#{plural}")
      end

      test "#{plural}: a new entry joins at the end" do
        model.create!(title: "Erstes")

        post route("admin_#{plural}"), params: {name => {title: "Neues"}}

        assert_redirected_to route("admin_#{plural}")
        assert_equal ["Erstes", "Neues"], model.order(:position).pluck(:title)
      end

      test "#{plural}: a new entry from the modal refreshes the page" do
        post route("admin_#{plural}"), params: {name => {title: "Neues"}}, as: :turbo_stream

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

      test "#{plural}: a new entry in the modal shows its errors there" do
        model.create!(title: "Vorhanden")

        post route("admin_#{plural}"), params: {name => {title: "Vorhanden"}}, as: :turbo_stream

        assert_response :unprocessable_content
        assert_select "turbo-stream[action=replace][target=#{form_id}]"
        assert_equal 1, model.count
      end

      test "#{plural}: the form for renaming an entry opens in a modal" do
        entry = model.create!(title: "Alt")

        get route("edit_admin_#{name}", entry), headers: TURBO_STREAM_HEADERS

        assert_response :success
        assert_equal "text/vnd.turbo-stream.html", response.media_type
        assert_select "turbo-stream[action=replace][target=#{modal_id}]"
        assert_includes response.body, %(id="#{form_id}")
      end

      test "#{plural}: an entry is renamed on a page of its own, submitted without Turbo" do
        entry = model.create!(title: "Alt")

        get route("edit_admin_#{name}", entry)

        assert_response :success
        assert_select "form[action=?][data-turbo=false]", route("admin_#{name}", entry)

        patch route("admin_#{name}", entry), params: {name => {title: "Neu"}}

        assert_redirected_to route("admin_#{plural}")
        assert_equal "Neu", entry.reload.title
      end

      test "#{plural}: an entry renamed in the modal refreshes the page" do
        entry = model.create!(title: "Alt")

        patch route("admin_#{name}", entry), params: {name => {title: "Neu"}}, as: :turbo_stream

        assert_response :success
        assert_select "turbo-stream[action=refresh]"
        assert_equal "Neu", entry.reload.title
      end

      test "#{plural}: an entry keeps its title when the new one is blank" do
        entry = model.create!(title: "Alt")

        patch route("admin_#{name}", entry), params: {name => {title: ""}}

        assert_response :unprocessable_content
        assert_equal "Alt", entry.reload.title
      end

      test "#{plural}: a rename in the modal shows its errors there" do
        entry = model.create!(title: "Alt")

        patch route("admin_#{name}", entry), params: {name => {title: ""}}, as: :turbo_stream

        assert_response :unprocessable_content
        assert_select "turbo-stream[action=replace][target=#{form_id}]"
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
