class RepostsController < ApplicationController
  def create
    @post = Post.find(params[:post_id])
    Current.user.reposts.create(post: @post)
    @post.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to posts_path }
    end
  end

  def destroy
    repost = Current.user.reposts.find_by!(post_id: params[:post_id])
    @post = repost.post
    repost.destroy
    @post.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to posts_path }
    end
  end
end
