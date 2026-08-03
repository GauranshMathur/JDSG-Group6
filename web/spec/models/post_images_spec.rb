require "rails_helper"

# F-7.2, F-7.3, F-7.4
RSpec.describe "Post images" do
  describe "attachment" do
    it "can have images attached" do
      post = create(:post)
      post.images.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/avatar.png")),
        filename: "photo.png",
        content_type: "image/png"
      )
      expect(post.images).to be_attached
    end

    it "rejects non-image content types" do
      post = create(:post)
      post.images.attach(
        io: StringIO.new("not an image"),
        filename: "hack.exe",
        content_type: "application/octet-stream"
      )
      expect(post).not_to be_valid
      expect(post.errors[:images]).to include("must be PNG, JPEG, WebP or GIF images")
    end

    it "limits the number of images per post" do
      post = create(:post)
      5.times do |i|
        post.images.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/avatar.png")),
          filename: "photo_#{i}.png",
          content_type: "image/png"
        )
      end
      expect(post).not_to be_valid
      expect(post.errors[:images]).to include("can have at most 4 images")
    end
  end

  describe "variants" do
    it "provides a feed-sized variant" do
      post = create(:post)
      post.images.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/avatar.png")),
        filename: "photo.png",
        content_type: "image/png"
      )
      variant = post.image_variants.first
      expect(variant).to be_present
    end
  end
end
