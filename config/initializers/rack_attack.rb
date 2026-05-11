class Rack::Attack
  LIMIT_STAMPS_CREATE = 30
  LIMIT_STAMPS_UPDATE = 60
  PERIOD = 60

  throttle("stamps/create", limit: LIMIT_STAMPS_CREATE, period: PERIOD) do |req|
    req.ip if req.post? && req.path == "/stamps"
  end

  throttle("stamps/update", limit: LIMIT_STAMPS_UPDATE, period: PERIOD) do |req|
    req.ip if req.patch? && req.path.match?(%r{\A/stamps/\w+/update_time\z})
  end

  self.throttled_responder = ->(env) {
    retry_after = (env["rack.attack.match_data"] || {})[:period] || PERIOD
    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
      [{ error: "Rate limit exceeded. Try again later." }.to_json]
    ]
  }
end