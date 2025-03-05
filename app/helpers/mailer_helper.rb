module MailerHelper

  def render_reminder_message(message, registration:)
    return "" if message.blank?

    message = message.gsub(/###NAME###/, render_name(registration))
    message = message.gsub(/###ANREDE###/, render_salutation(registration))
    message = message.gsub(/###DATUM###/, render_date(registration))
    message = message.gsub(/###UHRZEIT###/, render_time(registration))
    message = message.gsub(/###DAUER###/, render_duration(registration))
    message = message.gsub(/###TREFFPUNKT###/, render_location(registration))
    message = message.gsub(/###TITEL###/, render_title(registration))

    message.presence || ""
  end

  private

  def render_name(registration)
    registration.full_name
  end

  def render_salutation(registration)
    "Hallo #{registration.full_name}"
  end

  def render_date(registration)
    l(registration.event.date_and_time.to_date)
  end

  def render_time(registration)
    l(registration.event.date_and_time.to_time, format: "%H:%M")
  end

  def render_duration(registration)
    registration.event.duration&.to_s.presence || ""
  end

  def render_location(registration)
    registration.event.location.presence || "n.n."
  end

  def render_title(registration)
    registration.event.course.title
  end

end
