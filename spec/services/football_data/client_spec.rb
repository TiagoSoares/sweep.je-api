require "rails_helper"
require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.describe FootballData::Client do
  include ActiveSupport::Testing::TimeHelpers

  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:client) { described_class.new(token: "test-token", cache:) }
  let(:url) { "https://api.football-data.org/v4/competitions/WC/standings" }

  it "sends the auth header and parses JSON" do
    stub = stub_request(:get, url)
      .with(headers: { "X-Auth-Token" => "test-token" })
      .to_return(status: 200, body: { "standings" => [] }.to_json, headers: { "Content-Type" => "application/json" })

    expect(client.standings("WC")).to eq("standings" => [])
    expect(stub).to have_been_made.once
  end

  it "serves the fresh cache without hitting upstream again within the window" do
    stub = stub_request(:get, url).to_return(status: 200, body: { "ok" => 1 }.to_json)

    2.times { client.standings("WC") }

    expect(stub).to have_been_made.once
  end

  it "retries on 429 and then succeeds" do
    stub = stub_request(:get, url).to_return(
      { status: 429, body: "" },
      { status: 200, body: { "ok" => 1 }.to_json }
    )

    expect(client.standings("WC")).to eq("ok" => 1)
    expect(stub).to have_been_made.times(2)
  end

  it "serves the last-good copy when upstream later fails" do
    stub_request(:get, url).to_return(status: 200, body: { "v" => "good" }.to_json)
    client.standings("WC") # primes fresh + last-good

    travel 2.minutes do # fresh (60s) expired, last-good (1 day) still valid
      stub_request(:get, url).to_return(status: 500, body: "boom")
      expect(client.standings("WC")).to eq("v" => "good")
    end
  end

  it "raises Unavailable when upstream fails with no cached copy" do
    stub_request(:get, url).to_return(status: 500, body: "boom")
    expect { client.standings("WC") }.to raise_error(FootballData::Unavailable)
  end

  it "raises NotConfigured without a token" do
    expect { described_class.new(token: nil, cache:).standings("WC") }
      .to raise_error(FootballData::NotConfigured)
  end
end
