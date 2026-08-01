class LikesController < ApplicationController
  def create
    @post = Post.find(params[:post_id])
    Current.user.likes.create(post: @post)
    @post.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to posts_path }
    end
  end

  def destroy
    like = Current.user.likes.find_by!(post_id: params[:post_id])
    @post = like.post
    like.destroy
    @post.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to posts_path }
    end
  end
end
