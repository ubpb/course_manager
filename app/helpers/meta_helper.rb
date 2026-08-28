module MetaHelper

  # Build a <=160 char meta description from one or more markdown sources,
  # using the first non-blank one, falling back to a static site description.
  def meta_description_for(*sources, fallback: t("frontend.meta.default_description"))
    text = sources.map { |source| strip_markdown(source) }.find(&:present?).presence || fallback
    truncate(text, length: 160, separator: " ", omission: " …")
  end

  # The library as a schema.org entity. Everything else points at it by @id
  # (the website publisher, an offer's provider), so search engines see one
  # organization for the whole site instead of one per page.
  def organization_id = "#{root_url}#organization"

  def organization_reference
    {
      "@type" => "Organization",
      "@id" => organization_id,
      "name" => ApplicationConfig[:organization, :name, default: "Universitätsbibliothek Paderborn"],
      "url" => ApplicationConfig[:organization, :url, default: "https://www.ub.uni-paderborn.de"]
    }
  end

  # The full organization node. Rendered once, on the home page.
  def organization_json_ld
    data = {"@context" => "https://schema.org"}
             .merge(organization_reference)
             .merge("logo" => image_url("ub-logo.svg"))

    alternate_name = ApplicationConfig[:organization, :alternate_name]
    same_as = ApplicationConfig[:organization, :same_as, default: []]

    data["alternateName"] = alternate_name if alternate_name.present?
    data["sameAs"] = same_as if same_as.present?
    data
  end

  # This portal as a schema.org WebSite, published by the organization above.
  def website_json_ld
    {
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "@id" => "#{root_url}#website",
      "url" => root_url,
      "name" => t("application.app_name"),
      "description" => t("frontend.meta.default_description"),
      "inLanguage" => I18n.locale.to_s,
      "publisher" => {"@id" => organization_id}
    }
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
      "provider" => organization_reference
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
