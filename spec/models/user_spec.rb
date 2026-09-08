require "rails_helper"

RSpec.describe User, type: :model do
  it "normalises the email address" do
    user = create_admin(email_address: "  Admin@Example.COM ")
    expect(user.email_address).to eq("admin@example.com")
  end

  it "requires a name, a valid email address and a password" do
    user = User.new(name: "", email_address: "not-an-email", password: "")
    expect(user).not_to be_valid
    expect(user.errors.attribute_names).to include(:name, :email_address, :password)
  end

  it "rejects a duplicate email address regardless of case" do
    create_admin(email_address: "admin@example.com")
    duplicate = User.new(name: "x", email_address: "ADMIN@example.com", password: "p" * 12)
    expect(duplicate).not_to be_valid
  end

  it "authenticates with the right password only" do
    user = create_admin(password: "correct horse battery")
    expect(User.authenticate_by(email_address: user.email_address, password: "correct horse battery")).to eq(user)
    expect(User.authenticate_by(email_address: user.email_address, password: "wrong")).to be_nil
  end
end
