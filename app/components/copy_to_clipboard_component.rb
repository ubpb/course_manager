# A read only text field with a button that copies its value to the clipboard.
# The behaviour lives in the sidecar Stimulus controller (controller.js).
class CopyToClipboardComponent < ViewComponent::Base

  # value: the text to copy
  # label: accessible name of the text field (it has no visible label)
  def initialize(value:, label:)
    @value = value
    @label = label
  end

end
