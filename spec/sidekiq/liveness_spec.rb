# frozen_string_literal: true

RSpec.describe Sidekiq::Liveness do
  it "has a version number" do
    expect(Sidekiq::Liveness::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
