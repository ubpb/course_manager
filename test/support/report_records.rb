# A statistics report for an event. The tests only need one to exist, so it
# skips the validations of the many statistics fields.
module ReportRecords

  def create_report(event = @event)
    event.build_report(duration: 90, number_of_participants: 1, lecturer: "Schulungsteam").tap do |report|
      report.save!(validate: false)
    end
  end

end
