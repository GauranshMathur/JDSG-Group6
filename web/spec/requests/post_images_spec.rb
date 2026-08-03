require "rails_helper"

# F-7.2, F-7.5
RSpec.describe "Post images (requests)" do
  describe "POST /posts (with images)" do
    it "attaches images to a new post" do
      sign_in
      file = fixture_file_upload("avatar.png", "image/png")

      expect {
        post posts_path, params: { post: { body: "Check this out!", images: [ file ] } }
      }.to change(Post, :count).by(1)

      created = Post.last
      expect(created.images).to be_attached
    end

    it "creates a post without images when none are provided" do
      sign_in

      expect {
        post posts_path, params: { post: { body: "No images here" } }
      }.to change(Post, :count).by(1)

      expect(Post.last.images).not_to be_attached
    end
  end

  describe "GET / (feed with images)" do
    it "renders image tags for posts that have images" do
      p = create(:post, body: "Look at my photo")
      p.images.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/avatar.png")),
        filename: "photo.png",
        content_type: "image/png"
      )

      get posts_path

      expect(response.body).to include("post__images")
    end

    it "does not render an image container for posts without images" do
      create(:post, body: "Text only")

      get posts_path

      expect(response.body).not_to include("post__images")
    end
  end

  describe "GET /posts/:id (detail with images)" do
    it "shows images on the post detail page" do
      p = create(:post, body: "Detail photo")
      p.images.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/avatar.png")),
        filename: "photo.png",
        content_type: "image/png"
      )

      get post_path(p)

      expect(response.body).to include("post__images")
    end
  end

  describe "GET / (composer)" do
    it "has a file input for images" do
      sign_in
      get posts_path

      expect(response.body).to include('type="file"')
      expect(response.body).to include("images")
    end
  end
end
