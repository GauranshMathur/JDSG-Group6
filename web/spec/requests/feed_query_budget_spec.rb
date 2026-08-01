require "rails_helper"

# The feed must cost the same number of queries whatever it renders.
#
# This is the property network latency multiplies. On SQLite a query is a
# function call, so a page issuing one query per post looks fine; at a 100ms
# round trip the same page takes over two seconds. Asserting the budget here
# catches that before it exists, and costs nothing to run.
#
# Milestone 3 is where it would otherwise break: attributing posts to users
# means rendering post.user per row, which is the textbook N+1.
#
# See docs/latency.md — N-6.1 and N-6.2.
RSpec.describe "Feed query budget" do
  # One SELECT for the page of posts. Nothing else should be needed to render
  # the timeline for a signed-out visitor.
  ANONYMOUS_BUDGET = 1

  # Plus one lookup to resume the session from its cookie, and one batch lookup
  # for which posts the current user has liked.
  SIGNED_IN_BUDGET = 3

  describe "signed out" do
    it "issues a constant number of queries regardless of the number of posts" do
      create_list(:post, 1)
      one_post = count_queries { get posts_path }

      create_list(:post, PostsController::PAGE_SIZE - 1)
      full_page = count_queries { get posts_path }

      expect(one_post).to eq(ANONYMOUS_BUDGET)
      expect(full_page).to eq(ANONYMOUS_BUDGET)
    end

    it "does not issue a separate count query to decide on the pagination link" do
      create_list(:post, PostsController::PAGE_SIZE + 1)

      sql = queries_in { get posts_path }

      expect(response.body).to include("Load older posts")
      expect(sql.grep(/\bCOUNT\s*\(/i)).to be_empty
    end

    it "still issues a constant number of queries on a later page" do
      create_list(:post, PostsController::PAGE_SIZE * 2)
      get posts_path
      cursor = Post.timeline.limit(PostsController::PAGE_SIZE).last.cursor

      expect(count_queries { get posts_path(after: cursor) }).to eq(ANONYMOUS_BUDGET)
    end
  end

  describe "signed in" do
    it "issues a constant number of queries regardless of the number of posts" do
      sign_in
      create_list(:post, 1)
      one_post = count_queries { get posts_path }

      create_list(:post, PostsController::PAGE_SIZE - 1)
      full_page = count_queries { get posts_path }

      expect(one_post).to eq(SIGNED_IN_BUDGET)
      expect(full_page).to eq(SIGNED_IN_BUDGET)
    end
  end
end
