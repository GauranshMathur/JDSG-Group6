class SearchController < ApplicationController
  include TimelinePagination

  allow_unauthenticated_access

  def show
    @query = params[:q].to_s.strip

    if @query.present?
      @posts = page_of_posts(Post.search(@query).timeline)
      @next_cursor = next_cursor_for(@posts)
      @liked_post_ids = liked_post_ids_for(@posts)
      @reposted_post_ids = reposted_post_ids_for(@posts)
      @users = User.search(@query).limit(10)
    else
      @posts = []
      @users = []
    end
  end
end
