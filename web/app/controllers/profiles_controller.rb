class ProfilesController < ApplicationController
  include TimelinePagination

  # Reading is public; only writing needs an account (F-2.5).
  allow_unauthenticated_access only: :show

  def show
    @user = User.find_by!(username: params[:username].downcase)
    @posts = page_of_posts(@user.posts.timeline)
    @next_cursor = next_cursor_for(@posts)
    @liked_post_ids = liked_post_ids_for(@posts)
  end

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    if @user.update(profile_params)
      redirect_to profile_path(@user.username), notice: "Profile updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

    # No :username here — it is fixed at registration (ADR 0006). Strong
    # parameters drop it silently; attr_readonly on the model would raise if
    # anything got past them.
    def profile_params
      params.require(:user).permit(:display_name, :bio)
    end
end
