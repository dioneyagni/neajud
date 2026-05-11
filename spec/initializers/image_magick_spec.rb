require "rails_helper"

RSpec.describe "ImageMagick policy" do
  it "sets MAGICK_CONFIGURE_PATH to include config directory" do
    policy_dir = Rails.root.join("config").to_s
    expect(ENV["MAGICK_CONFIGURE_PATH"]).to include(policy_dir)
  end

  it "has a policy.xml file in the config directory" do
    policy_path = Rails.root.join("config", "image_policy.xml")
    expect(File.exist?(policy_path)).to be true
  end

  it "disallows PDF coder in policy" do
    policy_path = Rails.root.join("config", "image_policy.xml")
    content = File.read(policy_path)
    expect(content).to include('pattern="PDF"')
    expect(content).to include('rights="none"')
  end

  it "allows ImageMagick to process allowed formats" do
    result = `identify -list policy 2>&1`
    expect($?.success?).to be true
  end
end
