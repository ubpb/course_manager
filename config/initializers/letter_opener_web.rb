# The mails kept for reading (letter_opener_web, the default on a server) lie
# one level below tmp/letter_opener. On a server that directory is a link to
# one that survives deploys (config/deploy.rb), and the viewer's "Clear"
# removes the mails' directory with rm_rf: on the link itself it would remove
# only the link and leave the mails, which hold personal data.
#
# The delivery method takes the location when Action Mailer loads, after this.
LetterOpenerWeb.configure do |config|
  config.letters_location = Rails.root.join("tmp/letter_opener/letters")
end
