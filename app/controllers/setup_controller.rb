# First-run setup: Create Admin -> Enter Site URL. This is the only part of
# the product that requires a human, and it runs exactly once per deployment.
class SetupController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  prepend_before_action :reject_if_set_up

  def new
    redirect_to setup_site_path and return if User.exists?

    @user = User.new
  end

  def create
    redirect_to setup_site_path and return if User.exists?

    @user = User.new(user_params)
    if @user.save
      start_new_session_for @user
      redirect_to setup_site_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def site
    @site = Site.new
  end

  def create_site
    @site = Site.new(site_params)
    if @site.save
      redirect_to admin_root_path, notice: t("setup.completed")
    else
      render :site, status: :unprocessable_entity
    end
  end

  private

  def reject_if_set_up
    raise ActionController::RoutingError, "setup already completed" if User.exists? && Site.exists?
  end

  def user_params
    params.expect(user: %i[name email_address password password_confirmation])
  end

  def site_params
    params.expect(site: %i[name domain])
  end
end
