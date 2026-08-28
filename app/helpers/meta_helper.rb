module MetaHelper

  # Build a <=160 char meta description from one or more markdown sources,
  # using the first non-blank one, falling back to a static site description.
  def meta_description_for(*sources, fallback: t("frontend.meta.default_description"))
    text = sources.map { |source| strip_markdown(source) }.find(&:present?).presence || fallback
    truncate(text, length: 160, separator: " ", omission: " …")
  end

  # schema.org BreadcrumbList built from the controller breadcrumb trail.
  # Lets Google show "ub.uni-paderborn.de › Angebote › Schulungen › Titel"
  # instead of the bare URL in the search result. Trails shorter than two
  # linked crumbs carry no information and are skipped.
  def breadcrumb_json_ld
    crumbs = breadcrumb.select { |crumb| crumb[:path].present? }
    return if crumbs.size < 2

    {
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => crumbs.map.with_index(1) do |crumb, position|
        {
          "@type" => "ListItem",
          "position" => position,
          "name" => crumb[:label],
          "item" => URI.join(root_url, crumb[:path]).to_s
        }
      end
    }
  end

  # schema.org structured data (JSON-LD) for an offer.
  # Courses map to `Course`; consultings to `Service`.
  def offer_json_ld(offer, upcoming_events = [])
    data = {
      "@context" => "https://schema.org",
      "@type" => offer.consulting? ? "Service" : "Course",
      "name" => offer.title,
      "description" => meta_description_for(offer.description, offer.learning_targets),
      "url" => frontend_offer_url(offer),
      "provider" => {
        "@type" => "Organization",
        "name" => t("application.ub"),
        "url" => root_url
      }
    }

    topics = offer.topics.map(&:title)
    target_groups = offer.target_groups.map(&:title)
    data["about"] = topics if topics.any?
    data["audience"] = target_groups.map { |name| {"@type" => "Audience", "audienceType" => name} } if target_groups.any?

    if upcoming_events.present?
      data["hasCourseInstance"] = upcoming_events.map { |event| event_json_ld(event) }
    end

    data
  end

  def event_json_ld(event)
    instance = {
      "@type" => "CourseInstance",
      "courseMode" => event.online? ? "online" : "onsite",
      "startDate" => event.date_and_time.iso8601
    }
    instance["endDate"] = (event.date_and_time + event.duration.minutes).iso8601 if event.duration.present?
    instance["location"] = {"@type" => "Place", "name" => event.location} if event.location.present?
    instance
  end

end
