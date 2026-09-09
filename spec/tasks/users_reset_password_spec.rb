require "rails_helper"
require "rake"

RSpec.describe "users:reset_password", type: :task do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.empty? }

  it "sets a new password, prints it and ends existing sessions" do
    user = create_admin(password: "old password 123")
    user.sessions.create!
    output = StringIO.new
    $stdout = output
    Rake::Task["users:reset_password"].invoke(user.email_address)
  ensure
    $stdout = STDOUT
    Rake::Task["users:reset_password"].reenable
    new_password = output.string[/: (\S+)\s*\z/, 1]
    expect(new_password).to be_present
    expect(User.authenticate_by(email_address: user.email_address, password: new_password)).to eq(user)
    expect(User.authenticate_by(email_address: user.email_address, password: "old password 123")).to be_nil
    expect(user.sessions.count).to eq(0)
  end
end
