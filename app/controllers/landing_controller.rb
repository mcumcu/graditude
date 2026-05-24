class LandingController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    @background_image = "landing-hero.jpg"
    @landing_info = "A gift for the people who got you here."
    @landing_info_path = product_path
    @landing_title = "Express your Graditude"
    @landing_subtitle = "Celebrate your graduation by creating personalized certificates for the parents, mentors, coaches, and others who supported you along the way."
    @landing_cta_text = "Explore the certificate"
    @landing_cta_path = product_path
  end
end
