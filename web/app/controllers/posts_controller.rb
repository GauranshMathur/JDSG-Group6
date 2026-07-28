class PostsController < ApplicationController
  PAGE_SIZE = 20

  def index
    @post = Post.new
    @posts = page_of_posts
    @next_cursor = next_cursor_for(@posts)
  end

  def create
    @post = Post.new(post_params)

    if @post.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to posts_path }
      end
    else
      # The composer is re-rendered with its errors, so the timeline around it
      # has to be rebuilt too.
      @posts = page_of_posts
      @next_cursor = next_cursor_for(@posts)
      render :index, status: :unprocessable_content
    end
  end

  private

  def post_params
    params.require(:post).permit(:body, :author_name)
  end

  def page_of_posts
    scope = Post.timeline
    cursor = Post.parse_cursor(params[:after])
    scope = scope.older_than(*cursor) if cursor
    scope.limit(PAGE_SIZE)
  end

  # Only offer a "load older" link when this page filled up. A short page means
  # the end of the timeline has been reached.
  def next_cursor_for(posts)
    posts.last.cursor if posts.size == PAGE_SIZE
  end
end
