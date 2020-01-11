class SessionsController < ApplicationController
  before_action :authenticate, only: [:refresh, :destroy]

  def login
    raise CustomError::BadRequest unless params[:provider]
    raise CustomError::BadRequest unless params[:callback]
    redirect_to "/auth/#{params[:provider]}?redirect=#{params[:callback]}"
  end

  def create
    user = User.find_or_create_from_auth(request.env["omniauth.auth"])
    token = user.token
    url = request.env["omniauth.params"]["redirect"]
    redirect_to "#{url}?token=#{token}"
  end

  def refresh
    @auth_user.regenerate_token
    @auth_user.save!
    render json: { token: @auth_user.token }
  end

  def destroy
    @auth_user.regenerate_token
    @auth_user.save!
    render json: {}
  end

  def failure
    p request.fullpath
    p request.env["omniauth.params"]
    #redirect_to request.env['omniauth.params']['origin']
  end
end
