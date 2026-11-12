# What the admin says about how a participant registered: with the library
# account, as a guest or entered by staff. For a registration anonymized before
# the origin was recorded it is unknown, and nothing is said.
module AdminOriginHelper

  # Per origin: the label for the participant list and its export, and the icon
  # and the sentence for the participant form.
  ORIGINS = {
    "account" => {label: "Konto", icon: "fa-user-check", hint: "Mit Bibliothekskonto angemeldet"},
    "guest" => {label: "Gast", icon: "fa-user", hint: "Als Gast angemeldet"},
    "admin" => {label: "Admin", icon: "fa-user-pen", hint: "Im Admin eingetragen"}
  }.freeze

  def origin_label(registration)
    ORIGINS.dig(registration.origin, :label)
  end

  # [icon, sentence], or nil when the origin is unknown.
  def origin_hint(registration)
    ORIGINS[registration.origin]&.values_at(:icon, :hint)
  end

end
