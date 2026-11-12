# What the participant list and its export say about how a participant
# registered: with the library account, as a guest or entered by staff. For a
# registration anonymized before the origin was recorded it is unknown, and the
# cell stays empty.
module AdminOriginHelper

  ORIGIN_LABELS = {"account" => "Konto", "guest" => "Gast", "admin" => "Admin"}.freeze

  def origin_label(registration)
    ORIGIN_LABELS[registration.origin]
  end

end
