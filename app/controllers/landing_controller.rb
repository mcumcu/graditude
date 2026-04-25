class LandingController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    @background_image = "landing-hero.jpg"
    @landing_info = "Show your appreciation with a personalized certificate"
    @landing_info_path = new_certificate_path
    @landing_title = "Express your Graditude"
    @landing_subtitle = "Giftable certificates for parents, mentors, and more"
    @landing_cta_text = "Get started"
    @landing_cta_path = new_certificate_path
  end
end
