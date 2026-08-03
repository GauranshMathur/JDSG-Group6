require "rails_helper"

# The feed must cost a bounded number of queries regardless of page content.
#
# The ranked feed loads posts and reposts, then sorts in memory. The query
# count is constant per page — it does not grow with the number of posts.
#
# See docs/latency.md — N-6.1 and N-6.2.
RSpec.describe "Feed query budget" do
  describe "signed out" do
    it "issues a constant number of queries regardless of the number of posts" do
      create_list(:post, 1)
      one_post = count_queries { get posts_path }

      create_list(:post, RankedFeed::PAGE_SIZE - 1)
      full_page = count_queries { get posts_path }

      expect(one_post).to eq(full_page)
    end

    it "does not issue a separate count query to decide on the pagination link" do
      create_list(:post, RankedFeed::PAGE_SIZE + 1)

      sql = queries_in { get posts_path }

      expect(response.body).to include("Load more")
      expect(sql.grep(/\bCOUNT\s*\(/i)).to be_empty
    end
  end

  describe "signed in" do
    it "issues a constant number of queries regardless of the number of posts" do
      sign_in
      create_list(:post, 1)
      one_post = count_queries { get posts_path }

      create_list(:post, RankedFeed::PAGE_SIZE - 1)
      full_page = count_queries { get posts_path }

      expect(one_post).to eq(full_page)
    end
  end
end
