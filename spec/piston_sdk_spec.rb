# frozen_string_literal: true

require "net/http"

RSpec.describe PistonSDK do
  it "has a version number" do
    expect(PistonSDK::VERSION).not_to be nil
  end

  it "fetches runtimes" do
    client = PistonSDK::Client.new
    runtimes = client.runtimes

    expect(runtimes.any? { |runtime| runtime.language == "ruby" }).to eq(true)
  end

  it "executes code successfully" do
    res = Net::HTTPOK.new("1.1", "200", "OK")
    res.instance_variable_set(:@read, true)
    res.instance_variable_set(
      :@body,
      '{
        "language": "ruby",
        "version": "3.0.1",
        "run": {
          "stdout": "42\n",
          "stderr": "",
          "output": "42\n",
          "code": 0,
          "signal": null,
          "message": null,
          "status": null,
          "cpu_time": null,
          "wall_time": null,
          "memory": null
        }
      }'
    )

    http_double = instance_double(Net::HTTP)

    allow(http_double).to receive(:is_a?)
      .with(Net::HTTP)
      .and_return(true)

    allow(http_double).to receive(:use_ssl=)
      .with(true)

    allow(Net::HTTP).to receive(:new)
      .with("emkc.org", 443)
      .and_return(http_double)

    expect(http_double).to receive(:request)
      .and_return(res)

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

  it "fails when request fails" do
    res = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
    res.instance_variable_set(:@read, true)
    res.instance_variable_set(
      :@body,
      '{"message": "Request failed"}'
    )

    http_double = instance_double(Net::HTTP)

    allow(http_double).to receive(:is_a?)
      .with(Net::HTTP)
      .and_return(true)

    allow(http_double).to receive(:use_ssl=)
      .with(true)

    allow(Net::HTTP).to receive(:new)
      .with("emkc.org", 443)
      .and_return(http_double)

    expect(http_double).to receive(:request)
      .and_return(res)

    client = PistonSDK::Client.new
    client.add_file(content: "puts 42", name: "app.rb")
    expect do
      client.execute(language: "ruby", version: "3.0.1")
    end.to raise_error(
      "Request failed with status code #{res.code}, #{res.body}"
    )
  end

  it "retries code execution due to rate limits" do
    first_res = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")

    second_res = Net::HTTPOK.new("1.1", "200", "OK")
    second_res.instance_variable_set(:@read, true)
    second_res.instance_variable_set(
      :@body,
      '{
        "language": "ruby",
        "version": "3.0.1",
        "run": {
          "stdout": "42\n",
          "stderr": "",
          "output": "42\n",
          "code": 0,
          "signal": null,
          "message": null,
          "status": null,
          "cpu_time": null,
          "wall_time": null,
          "memory": null
        }
      }'
    )

    http_double = instance_double(Net::HTTP)

    allow(http_double).to receive(:is_a?)
      .with(Net::HTTP)
      .and_return(true)

    allow(http_double).to receive(:use_ssl=)
      .with(true)

    allow(Net::HTTP).to receive(:new)
      .with("emkc.org", 443)
      .and_return(http_double)

    expect(http_double).to receive(:request)
      .and_return(
        first_res,
        second_res
      )

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

  it "fails when retries are exhausted" do
    res = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")

    http_double = instance_double(Net::HTTP)

    allow(http_double).to receive(:is_a?)
      .with(Net::HTTP)
      .and_return(true)

    allow(http_double).to receive(:use_ssl=)
      .with(true)

    allow(Net::HTTP).to receive(:new)
      .with("emkc.org", 443)
      .and_return(http_double)

    expect(http_double).to receive(:request)
      .and_return(
        res,
        res,
        res
      )

    client = PistonSDK::Client.new
    client.add_file(content: "puts 42", name: "app.rb")
    expect do
      client.execute(language: "ruby", version: "3.0.1")
    end.to raise_error(
      "Request failed due to rate limits after too many attempts"
    )
  end

  it "executes code against public Piston instance" do
    skip("As of Feb 15, 2026, public version of Piston is no longer available")

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

  it "fails with unsupported language against public Piston instance" do
    skip("As of Feb 15, 2026, public version of Piston is no longer available")

    client = PistonSDK::Client.new
    client.add_file(content: "puts 42", name: "app.rb")
    expect do
      client.execute(language: "foobar", version: "1.0")
    end.to raise_error('Request failed with status code 400, {"message":"foobar-1.0 runtime is unknown"}')
  end

  it "fails with no files against public Piston instance" do
    skip("As of Feb 15, 2026, public version of Piston is no longer available")

    client = PistonSDK::Client.new
    expect do
      client.execute(language: "ruby", version: "3.0.1")
    end.to raise_error(
      'Request failed with status code 400, {"message":"files must include at least one utf8 encoded file"}'
    )
  end
end
