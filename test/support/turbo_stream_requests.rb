# What Turbo sends for a link or form with data-turbo-stream, for tests that
# request the answers meant for a modal.
module TurboStreamRequests

  TURBO_STREAM_HEADERS = {
    "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
  }.freeze

end
