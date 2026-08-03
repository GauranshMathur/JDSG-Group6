require "rails_helper"

# F-7.1, F-7.3, F-7.4
RSpec.describe User, "avatar" do
  let(:avatar_file) { fixture_file_upload("avatar.png", "image/png") }

  describe "attachment" do
    it "can have an avatar attached" do
      user = create(:user)
      user.avatar.attach(avatar_file)

      expect(user.avatar).to be_attached
    end

    it "rejects non-image content types" do
      user = create(:user)
      user.avatar.attach(
        io: StringIO.new("not an image"),
        filename: "hack.txt",
        content_type: "text/plain"
      )

      expect(user).not_to be_valid
      expect(user.errors[:avatar]).to be_present
    end
  end

  describe "variants" do
    it "provides a thumbnail variant" do
      user = create(:user)
      user.avatar.attach(avatar_file)

      expect(user).to respond_to(:avatar_thumbnail)
    end
  end
end
