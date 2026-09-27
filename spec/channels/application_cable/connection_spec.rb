require "rails_helper"

# Live updates (Turbo Streams over Action Cable, Etapa 0.3) must not leak to
# signed-out visitors either.
RSpec.describe ApplicationCable::Connection, type: :channel do
  it "accepts a signed-in session cookie" do
    session = create(:user).sessions.create!
    cookies.signed[:session_id] = session.id
    connect
    expect(connection.current_user).to eq(session.user)
  end

  it "rejects a connection without a session" do
    expect { connect }.to have_rejected_connection
  end
end
