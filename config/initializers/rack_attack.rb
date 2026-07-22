class Rack::Attack
  LIMIT_ARQUIVOS_CREATE = 30
  LIMIT_ARQUIVOS_UPDATE = 60
  PERIOD = 60

  throttle("arquivos/create", limit: LIMIT_ARQUIVOS_CREATE, period: PERIOD) do |req|
    req.ip if req.post? && req.path == "/arquivos"
  end

  throttle("arquivos/update", limit: LIMIT_ARQUIVOS_UPDATE, period: PERIOD) do |req|
    req.ip if req.patch? && req.path.match?(%r{\A/arquivos/\w+/update_time\z})
  end

  self.throttled_responder = ->(env) {
    retry_after = (env["rack.attack.match_data"] || {})[:period] || PERIOD
    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
      [ { error: "Rate limit exceeded. Try again later." }.to_json ]
    ]
  }
end
