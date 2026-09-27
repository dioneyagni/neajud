require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#autor_do_log" do
    it "names the user, falling back to the IP of older logs" do
      com_user = ExclusaoLog.new(user: build(:user, nome: "Ana"), changed_by: "10.0.0.1")
      so_ip = ExclusaoLog.new(changed_by: "10.0.0.1")
      expect([ helper.autor_do_log(com_user), helper.autor_do_log(so_ip), helper.autor_do_log(nil) ]).to eq([ "Ana", "10.0.0.1", nil ])
    end
  end
end
