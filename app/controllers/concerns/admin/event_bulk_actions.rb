module Admin
  # The bulk actions of the event lists, the global one and the one of an
  # offer: publish, unpublish and move to another course. The including
  # controller names the events of its list (#bulk_events), the courses they
  # may move to (#bulk_target_offers) and the way back (#bulk_return_path).
  module EventBulkActions

    extend ActiveSupport::Concern

    def bulk_process
      events = bulk_events.where(id: params[:bulk_process_ids])

      # Every branch ends in the redirect below, so the flash messages must not be
      # flash.now (the cop misreads the case branches). update_all on purpose: one
      # old, invalid record must not stop a bulk change.
      # rubocop:disable-next Rails/ActionControllerFlashBeforeRender, Rails/SkipsModelValidations
      case params[:bulk_process_action]
      when "publish"
        events.update_all(published: true)
        flash[:success] = "Termin(e) wurde(n) veröffentlicht"
      when "unpublish"
        events.update_all(published: false)
        flash[:success] = "Veröffentlichung von Termin(en) wurde zurückgezogen"
      when "move_to_offer"
        return render_move_to_offer_form(events) if events.any?

        flash[:alert] = "Bitte mindestens einen Termin auswählen"
      end

      redirect_to bulk_return_path
    end

    def bulk_move
      events = bulk_events.where(id: params[:event_ids])
      offer = bulk_target_offers.find_by(id: params[:target_offer_id])

      if offer.nil? || events.none?
        flash[:alert] = "Bitte Termine und Ziel-Angebot auswählen"
      else
        events.update_all(offer_id: offer.id) # rubocop:disable Rails/SkipsModelValidations -- see bulk_process
        flash[:success] = "Termin(e) wurde(n) nach \"#{offer.title}\" verschoben"
      end

      redirect_to bulk_return_path
    end

    private

    def setup_bulk_process_actions(events)
      @bulk_process_actions = []
      return if events.empty?

      @bulk_process_actions << ["Veröffentlichen", "publish"]
      @bulk_process_actions << ["Veröffentlichung zurückziehen", "unpublish"]
      @bulk_process_actions << ["In anderes Angebot verschieben", "move_to_offer"]
    end

    # The dialog for picking the target offer, opened as a modal.
    def render_move_to_offer_form(events)
      render turbo_stream: turbo_stream.replace(
        "bulk-action-form",
        partial: "admin/events/bulk_action_move_to_offer",
        locals: {
          events: events.includes(:offer),
          offers: bulk_target_offers.order(:title),
          url: url_for(action: :bulk_move, only_path: true)
        }
      )
    end

  end
end
