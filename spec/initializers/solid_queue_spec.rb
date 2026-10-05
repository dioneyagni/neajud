require "rails_helper"

# Regression (05/10/2026): routes load lazily outside eager_load, and a fresh
# Solid Queue worker running two card broadcasts at once raced drawing them —
# one job failed with "undefined method 'arquivo_path'" and its file stayed
# "failed". config/initializers/solid_queue.rb draws them on worker start.
RSpec.describe "Solid Queue worker start" do
  it "draws the routes before the worker takes any job" do
    expect(Rails.application).to receive(:reload_routes_unless_loaded)
    SolidQueue::Worker.lifecycle_hooks[:start].each { |hook| hook.call(nil) }
  end
end
