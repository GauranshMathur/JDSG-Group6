require "rails_helper"

# F-4.9. The browser tab carries the app's own mark rather than the red circle
# the Rails generator ships, and the file it points at actually exists — a
# favicon link to a missing asset fails silently in a way nobody notices.
RSpec.describe "Favicon" do
  it "points the icon link at the logo" do
    get posts_path

    expect(response.body).to match(/<link[^>]*rel="icon"[^>]*twitter-logo[^>]*>/)
  end

  it "does not still link the generator's placeholder svg" do
    get posts_path

    expect(response.body).not_to include('href="/icon.svg"')
  end

  it "serves the logo the link points at" do
    expect(Rails.root.join("app/assets/images/twitter-logo.svg")).to exist
  end

  # The SVG is the source; public/icon.png is rasterized from it because an
  # apple-touch-icon cannot be an SVG. Keeping a second .svg in public/ as well
  # would be a copy free to drift from the one the app actually renders.
  it "keeps the raster icon the apple-touch-icon link needs" do
    expect(Rails.root.join("public/icon.png")).to exist
    expect(Rails.root.join("public/icon.svg")).not_to exist
  end
end
