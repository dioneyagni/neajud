policy_dir = Rails.root.join("config").to_s
ENV["MAGICK_CONFIGURE_PATH"] = [ENV["MAGICK_CONFIGURE_PATH"], policy_dir].compact.join(":")
