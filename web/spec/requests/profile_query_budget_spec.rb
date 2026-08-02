require "rails_helper"

# The same property the feed budget asserts (N-6.1, N-6.2), on the page added
# in milestone 4: rendering a profile must cost a constant number of queries
# however many posts it shows.
RSpec.describe "Profile query budget" do
  it "issues a constant number of queries regardless of the number of posts" do
    ada = create(:user, username: "ada")

    create_list(:post, 1, user: ada)
    one_post = count_queries { get profile_path("ada") }

    create_list(:post, ProfileFeed::PAGE_SIZE - 1, user: ada)
    full_page = count_queries { get profile_path("ada") }

    expect(one_post).to eq(full_page)
  end

  it "stays constant signed in" do
    ada = create(:user, username: "ada")
    create_list(:post, ProfileFeed::PAGE_SIZE, user: ada)

    sign_in
    one_page = count_queries { get profile_path("ada") }
    expect(one_page).to be > 0
  end

  it "does not issue a separate count query to decide on the pagination link" do
    ada = create(:user, username: "ada")
    create_list(:post, ProfileFeed::PAGE_SIZE + 1, user: ada)

    sql = queries_in { get profile_path("ada") }

    expect(response.body).to include("Load more")
    expect(sql.grep(/\bCOUNT\s*\(/i)).to be_empty
  end
end
