require "test_helper"

class CopyToClipboardComponentTest < ViewComponent::TestCase

  URL = "https://uni-paderborn.zoom-x.de/j/62012345678?pwd=abc".freeze

  # Read only, but not disabled: the text has to stay selectable, so it can
  # still be copied by hand where the clipboard API is not available.
  test "the value sits in a selectable read only field" do
    render_inline(CopyToClipboardComponent.new(value: URL, label: "Zugangslink"))

    assert_selector "input[type=text][readonly][value='#{URL}'][aria-label='Zugangslink']"
    assert_no_selector "input[disabled]"
  end

  test "the button copies through the stimulus controller" do
    render_inline(CopyToClipboardComponent.new(value: URL, label: "Zugangslink"))

    assert_selector "[data-controller='copy-to-clipboard-component']"
    assert_selector "button[type=button][data-action='copy-to-clipboard-component#copy'][title='In die " \
                    "Zwischenablage kopieren']",
                    text: "Kopieren"
    assert_selector "[data-copy-to-clipboard-component-target='copied'][hidden]", text: "Kopiert", visible: :all
  end

  test "the outcome is announced to screen readers" do
    render_inline(CopyToClipboardComponent.new(value: URL, label: "Zugangslink"))

    assert_selector "[aria-live=polite][data-copy-to-clipboard-component-target='status']", visible: :all
  end

end
