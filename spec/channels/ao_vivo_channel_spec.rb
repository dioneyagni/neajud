require "rails_helper"

# Etapa 2.8 (3b): the live updates' channel checks who listens, not only the
# name's signature (CanaisAoVivo.permitido?).
RSpec.describe AoVivoChannel, type: :channel do
  let(:client) { create(:client) }
  let(:cliente_final) { create(:vinculo, user: create(:user), client: client).user }

  it "streams the client's cards to its cliente final" do
    stub_connection current_user: cliente_final
    subscribe signed_stream_name: CanaisAoVivo.assinar("cartoes:#{client.uuid}")
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("cartoes:#{client.uuid}")
  end

  it "rejects the team's cards for a cliente final, though the name is signed" do
    stub_connection current_user: cliente_final
    subscribe signed_stream_name: CanaisAoVivo.assinar(CanaisAoVivo::EQUIPE)
    expect(subscription).to be_rejected
  end

  it "rejects a name signed by Turbo or tampered with" do
    stub_connection current_user: create(:vinculo).user
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name(CanaisAoVivo::EQUIPE)
    expect(subscription).to be_rejected
  end
end
