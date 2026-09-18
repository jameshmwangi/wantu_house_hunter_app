module ListingsHelper
  LISTING_STATUS_BADGE = {
    'published' => 'success',
    'draft'     => 'secondary',
    'hidden'    => 'warning'
  }.freeze

  def listing_status_badge(listing)
    colour = LISTING_STATUS_BADGE.fetch(listing.status, 'secondary')
    content_tag(:span, t("listings.status.#{listing.status}"), class: "badge bg-#{colour}")
  end
end
