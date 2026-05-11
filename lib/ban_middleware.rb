class BanMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    ip = Rack::Request.new(env).ip

    if banned?(ip)
      [ 403, { "Content-Type" => "application/json" }, [ { error: "Your IP has been banned." }.to_json ] ]
    else
      @app.call(env)
    end
  end

  private

  def banned?(ip)
    Ban.active.exists?(ip_address: ip)
  rescue => e
    Rails.logger.error "[BanMiddleware] #{e.message}"
    false
  end
end
