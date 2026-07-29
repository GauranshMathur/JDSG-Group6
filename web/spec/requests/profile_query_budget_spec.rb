require "rails_helper"

# The same property the feed budget asserts (N-6.1, N-6.2), on the page added
# in milestone 4: rendering a profile must cost a constant number of queries
# however many posts it shows.
RSpec.describe "Profile query budget" do
  # Constants assigned in a describe block land on Object, not the example
  # group, so names here would collide with the feed budget spec's. let keeps
  # them scoped.

  # One SELECT to find the user by username, one for their page of posts.
  let(:anonymous_budget) { 2 }

  # Plus one lookup to resume the session from its cookie.
  let(:signed_in_budget) { 3 }

  it "issues a constant number of queries regardless of the number of posts" do
    ada = create(:user, username: "ada")

    create_list(:post, 1, user: ada)
    one_post = count_queries { get profile_path("ada") }

    create_list(:post, TimelinePagination::PAGE_SIZE - 1, user: ada)
    full_page = count_queries { get profile_path("ada") }

    expect(one_post).to eq(anonymous_budget)
    expect(full_page).to eq(anonymous_budget)
  end

  it "stays constant signed in" do
    ada = create(:user, username: "ada")
    create_list(:post, TimelinePagination::PAGE_SIZE, user: ada)
    sign_in

    expect(count_queries { get profile_path("ada") }).to eq(signed_in_budget)
  end

  it "does not issue a separate count query to decide on the pagination link" do
    ada = create(:user, username: "ada")
    create_list(:post, TimelinePagination::PAGE_SIZE + 1, user: ada)

    sql = queries_in { get profile_path("ada") }

    expect(response.body).to include("Load older posts")
    expect(sql.grep(/COUNT/i)).to be_empty
  end
end
