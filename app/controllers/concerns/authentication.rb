module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    before_action :exigir_troca_de_senha
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    # After a provisional password (Etapa 0.5, 3/4) nothing else opens until
    # it is changed; signing out stays possible.
    def exigir_troca_de_senha
      return unless Current.user&.trocar_senha?
      return if is_a?(SenhasController) || is_a?(SessionsController)

      redirect_to edit_senha_path, alert: "Choose your own password to continue."
    end

    # A deactivated user's sessions are destroyed on deactivation; the join
    # also guards any session created in between, and a cliente final whose
    # client went to the trash (User.com_acesso).
    def find_session_by_cookie
      Session.joins(:user).merge(User.com_acesso).find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    # A new instance has nobody to sign in as yet: send to the first-access
    # setup (ConfiguracaoController) instead.
    def request_authentication
      return redirect_to configuracao_path unless User.exists?

      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || pagina_inicial(Current.user)
    end

    # A cliente final starts on his pedidos (Etapa 2.8, 2/5) while his grid
    # shows them (3a); the team, on the gallery.
    # Usage: redirect_to pagina_inicial(user)
    def pagina_inicial(user)
      cliente = user.cliente
      cliente && TiposParaCliente.abertos_para(cliente).include?("pedidos") ? pedidos_url : root_url
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
