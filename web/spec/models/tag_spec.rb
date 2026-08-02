require "rails_helper"

# F-5.1, F-5.2, F-5.3
RSpec.describe Tag do
  describe "validations" do
    it "requires a name" do
      tag = Tag.new
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to be_present
    end

    it "enforces uniqueness of name" do
      Tag.create!(name: "rails")
      duplicate = Tag.new(name: "rails")
      expect(duplicate).not_to be_valid
    end
  end

  # F-5.3
  describe "normalisation" do
    it "normalises the name to lower case" do
      tag = Tag.create!(name: "Rails")
      expect(tag.reload.name).to eq("rails")
    end

    it "strips whitespace from the name" do
      tag = Tag.create!(name: "  rails  ")
      expect(tag.reload.name).to eq("rails")
    end
  end
end
