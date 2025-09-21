# frozen_string_literal: true

RSpec.describe PistonSDK do
  it "has a version number" do
    expect(PistonSDK::VERSION).not_to be nil
  end

  it "fetches runtimes" do
    client = PistonSDK::Client.new
    runtimes = client.runtimes

    expect(runtimes.any? { |runtime| runtime.language == "ruby" }).to eq(true)
  end

  it "executes code" do
    client = PistonSDK::Client.new
    client.add_file(content: "puts 42", name: "app.rb")
    results = client.execute(language: "ruby", version: "3.0.1")

    expect(results.language).to eq("ruby")
    expect(results.version).to eq("3.0.1")
    expect(results.run).not_to be_nil
    expect(results.run.stdout).to eq("42\n")
    expect(results.run.stderr).to eq("")
    expect(results.run.output).to eq("42\n")
    expect(results.run.code).to eq(0)
  end

  it "unsupported language" do
    client = PistonSDK::Client.new
    client.add_file(content: "puts 42", name: "app.rb")
    expect do
      client.execute(language: "foobar", version: "1.0")
    end.to raise_error('Request failed with status code 400, {"message":"foobar-1.0 runtime is unknown"}')
  end

  it "no files" do
    client = PistonSDK::Client.new
    expect do
      client.execute(language: "ruby", version: "3.0.1")
    end.to raise_error(
      'Request failed with status code 400, {"message":"files must include at least one utf8 encoded file"}'
    )
  end
end
