require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid with factory defaults" do
    expect(build(:user)).to be_valid
  end

  it "assigns a ULID public_id on create" do
    user = create(:user)
    expect(user.public_id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
  end

  it "normalizes email to lowercase and strips whitespace" do
    user = create(:user, email: "  MixedCase@Example.COM ")
    expect(user.email).to eq("mixedcase@example.com")
  end

  it "requires a name" do
    expect(build(:user, name: "")).not_to be_valid
  end

  it "rejects a short password" do
    expect(build(:user, password: "short")).not_to be_valid
  end

  it "enforces unique emails case-insensitively" do
    create(:user, email: "dup@example.com")
    expect(build(:user, email: "DUP@example.com")).not_to be_valid
  end

  it "defaults to the organizer role" do
    expect(create(:user).role).to eq("organizer")
  end

  it "authenticates with the correct password" do
    user = create(:user, password: "password123")
    expect(user.authenticate("password123")).to be_truthy
    expect(user.authenticate("nope")).to be_falsey
  end
end
