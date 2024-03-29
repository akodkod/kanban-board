class OmniauthController < ApplicationController
  # Settings
  layout 'authentication'

  # Callbacks
  skip_before_action :authentication_required!

  def sign_oauth2
    if omniauth_user_by_provider
      user_sign_in(omniauth_user_by_provider)
      redirect_to root_path
    else
      store_omniauth_data

      if user_signed_in? || omniauth_user_by_email
        redirect_to omniauth_url
      else
        puts 'haha'
        render 'auth/sign_up', locals: { user: User.new(user_params_from_omniauth) }
      end
    end
  end

  def omniauth
    service = UserServices::Omniauth.run!(params, omniauth_data, current_user: current_user)

    if service.success?
      delete_omniauth_data

      if user_signed_in?
        redirect_to user_url(service.user), flash: { success: 'Account successfully connected' }
      else
        if service.user.blocked?
          redirect_to sign_in_path, flash: { notice: 'Account successfully created. Please wait for activation' }
        else
          user_sign_in(service.user)
          redirect_to root_path
        end
      end
    else
      if user_signed_in?
        render 'users/edit', locals: { user: service.user, errors: service.errors }
      else
        render 'auth/sign_up', locals: { user: User.new, errors: service.errors }
      end
    end
  end

  private

  def omniauth_user_by_provider
    return @omniauth_user if defined?(@omniauth_user)
    @omniauth_user = UserAccount
                       .find_by(
                         uid: request.env['omniauth.auth']['uid'],
                         provider: request.env['omniauth.auth']['provider']
                       )&.user
  end

  def omniauth_user_by_email
    return @omniauth_user_by_email if defined?(@omniauth_user_by_email)
    @omniauth_user_by_email = User.find_by(email: request.env['omniauth.auth']['info']['email'])
  end

  def omniauth_data
    session[:omniauth_data]
  end

  def store_omniauth_data
    session[:omniauth_data] = request.env['omniauth.auth']
  end

  def delete_omniauth_data
    session.delete(:omniauth_data)
  end

  def user_params_from_omniauth
    {
      name: omniauth_data.dig('info', 'name'),
      email: omniauth_data.dig('info', 'email')
    }
  end
end
