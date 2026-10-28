module Admin
  # Forms that open in a modal on top of a list. The list links `new` and
  # `edit` with data-turbo-stream, holds an empty `#<name>-modal` and keeps its
  # scroll position on refresh (meta turbo-refresh-scroll). The `_modal`
  # partial renders `_form`, whose root is `#<name>-form.modal-content`.
  # <name> comes from the controller: "topic", "target-group", "registration".
  #
  # A visit without Turbo gets the form as a page of its own, whose form
  # submits without Turbo.
  module ModalForm

    extend ActiveSupport::Concern

    private

    def modal_form_name
      controller_name.singularize.dasherize
    end

    # The list opens the form in a modal; a visit without Turbo gets it as a page.
    def respond_with_modal(**locals)
      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("#{modal_form_name}-modal", partial: "modal", locals: locals)
        end
      end
    end

    # Only swap the content of the already open modal — replacing the whole
    # container would spawn a second modal on top of it.
    def respond_with_errors(template, **locals)
      respond_to do |format|
        format.html { render template, status: :unprocessable_content }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("#{modal_form_name}-form", partial: "form", locals: locals),
                 status: :unprocessable_content
        end
      end
    end

    # The refresh morphs the page the modal was opened on into its new state,
    # which also closes the modal. The notice shows on the refreshed page.
    def respond_with_list(path, notice: nil)
      respond_to do |format|
        format.html { redirect_to path, status: :see_other, **{notice: notice}.compact }
        format.turbo_stream do
          flash[:notice] = notice if notice
          render turbo_stream: turbo_stream.refresh(request_id: nil)
        end
      end
    end

  end
end
