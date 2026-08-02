class TagsController < ApplicationController
  include TimelinePagination

  allow_unauthenticated_access

  def show
    @tag = Tag.find_by!(name: params[:name].downcase)
    @posts = page_of_posts(@tag.posts.timeline)
    @next_cursor = next_cursor_for(@posts)
    @liked_post_ids = liked_post_ids_for(@posts)
    @reposted_post_ids = reposted_post_ids_for(@posts)
  end
end
