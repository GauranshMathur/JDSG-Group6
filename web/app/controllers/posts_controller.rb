class PostsController < ApplicationController
  PAGE_SIZE = 20

  # Reading is public; only writing needs an account. See docs/design-principles.md.
  allow_unauthenticated_access only: :index

  # Authorisation by scoping, not by checking (F-3.5). Every write loads the post
  # through Current.user.posts, so someone else's row is simply not found and
  # raises. A fetch-then-compare would work until the day the comparison is
  # forgotten, and then it would expose the row instead of refusing it.
  before_action :set_own_post, only: %i[ edit update destroy ]

  def index
    @post = Post.new
    @posts = page_of_posts
    @next_cursor = next_cursor_for(@posts)
  end

  def create
    @post = Current.user.posts.build(post_params)

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

  def edit
  end

  def update
    if @post.update(post_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to posts_path }
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @post.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to posts_path }
    end
  end

  private

  def set_own_post
    @post = Current.user.posts.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:body)
  end

  # Loaded here rather than left for the view, because next_cursor_for asks for
  # its size first. On an unloaded relation that size is a separate COUNT query,
  # and the rows are then fetched again to render — two round trips for one page
  # of posts. See docs/latency.md.
  def page_of_posts
    scope = Post.timeline
    cursor = Post.parse_cursor(params[:after])
    scope = scope.older_than(*cursor) if cursor
    scope.limit(PAGE_SIZE).load
  end

  # Only offer a "load older" link when this page filled up. A short page means
  # the end of the timeline has been reached.
  def next_cursor_for(posts)
    posts.last.cursor if posts.size == PAGE_SIZE
  end
end
