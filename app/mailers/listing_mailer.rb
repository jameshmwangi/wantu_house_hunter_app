class ListingMailer < ApplicationMailer
  def listing_published(listing)
    @listing = listing
    @user = listing.user
    mail(to: @user.email, subject: t('mailers.listing_published.subject', title: @listing.title))
  end
end
