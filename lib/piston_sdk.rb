# frozen_string_literal: true

require "net/http"
require "json"
require_relative "piston_sdk/version"

# A minimal Ruby gem for using the [Piston API](https://github.com/engineer-man/piston).
module PistonSDK
  # Data representation of a Piston runtime.
  class Runtime
    attr_reader :language, :version, :aliases, :runtime

    # Create a new Piston runtime.
    #
    # @param data [Hash] JSON data.
    def initialize(data)
      @language = data["language"]
      @version = data["version"]
      @aliases = data["aliases"]
      @runtime = data["runtime"]
    end
  end

  # Data representation of Piston execution step details.
  class ExecutionStepDetails
    attr_reader :stdout, :stderr, :output, :code, :signal, :message, :status, :cpu_time, :wall_time, :memory

    # Create new Piston execution step details.
    #
    # @param data [Hash] JSON data.
    def initialize(data)
      @stdout = data["stdout"] unless data["stdout"].nil?
      @stderr = data["stderr"] unless data["stderr"].nil?
      @output = data["output"] unless data["output"].nil?
      @code = data["code"] unless data["code"].nil?
      @signal = data["signal"] unless data["signal"].nil?
      @message = data["message"] unless data["message"].nil?
      @status = data["status"] unless data["status"].nil?
      @cpu_time = data["cpu_time"] unless data["cpu_time"].nil?
      @wall_time = data["wall_time"] unless data["wall_time"].nil?
      @memory = data["memory"] unless data["memory"].nil?
    end
  end

  # Data representation of Piston execution results.
  class ExecutionResults
    attr_reader :language, :version, :run, :compile

    # Create new Piston execution results.
    #
    # @param data [Hash] JSON data.
    def initialize(data)
      @language = data["language"]
      @version = data["version"]
      @run = ExecutionStepDetails.new(data["run"]) unless data["run"].nil?
      @compile = ExecutionStepDetails.new(data["compile"]) unless data["compile"].nil?
    end
  end

  # HTTP client for the Piston API.
  class Client
    # Create a new client.
    #
    # @param base_url [String] Base URL for API.
    # @param compile_timeout [Integer, nil] The maximum wall-time allowed for the compile stage to finish before bailing
    # out in milliseconds.
    # @param run_timeout [Integer, nil] The maximum wall-time allowed for the run stage to finish before bailing out in
    # milliseconds.
    # @param compile_cpu_time [Integer, nil] The maximum CPU-time allowed for the compile stage to finish before bailing
    # out in milliseconds.
    # @param run_cpu_time [Integer, nil] The maximum CPU-time allowed for the run stage to finish before bailing out in
    # milliseconds.
    # @param compile_memory_limit [Integer, nil] The maximum amount of memory the compile stage is allowed to use in
    # bytes.
    # @param run_memory_limit [Integer, nil] The maximum amount of memory the run stage is allowed to use in bytes.
    def initialize(
      base_url: "https://emkc.org/api/v2/piston",
      retries: 3,
      compile_timeout: nil,
      run_timeout: nil,
      compile_cpu_time: nil,
      run_cpu_time: nil,
      compile_memory_limit: nil,
      run_memory_limit: nil
    )
      @uri = URI(base_url)
      @retries = retries
      @compile_timeout = compile_timeout
      @run_timeout = run_timeout
      @compile_cpu_time = compile_cpu_time
      @run_cpu_time = run_cpu_time
      @compile_memory_limit = compile_memory_limit
      @run_memory_limit = run_memory_limit
      @files = []

      @http = Net::HTTP.new(@uri.host, @uri.port)
      @http.use_ssl = true

      @method_classes = Hash.new(Net::HTTP::Get)
      @method_classes[:get] = Net::HTTP::Get
      @method_classes[:post] = Net::HTTP::Post
    end

    # Perform raw HTTP request using exponential backoff on retries.
    #
    # @param method [Symbol] HTTP method.
    # @param path [String] URL Path.
    # @param body [Hash, nil] Optional request body
    # @return [Hash, Array] JSON response.
    def request(method: :get, path: "", body: nil)
      req = @method_classes[method].new("#{@uri}#{path}")
      req["Content-Type"] = "application/json"
      req.body = body.to_json unless body.nil?
      res = @http.request(req)

      (0...@retries).each do |attempt|
        res = @http.request(req)

        case res
        when Net::HTTPOK
          return JSON.parse(res.body)
        when Net::HTTPTooManyRequests
          sleep 2**attempt
        else
          raise "Request failed with status code #{res.code}, #{res.body}"
        end
      end
    end

    # Add file to be sent to Piston for execution.
    #
    # @param content [String] Content of the files to upload.
    # @param name [String, nil] Name of the file to upload.
    # @param encoding [String, nil] Encoding scheme used for the file content.
    def add_file(content:, name: nil, encoding: nil)
      file = {
        name: name,
        content: content,
        encoding: encoding
      }.compact

      @files << file
    end

    # Clear all files.
    def clear_files
      @files.clear
    end

    # Get supported languages along with the current version and aliases.
    #
    # @return [Array<Runtime>] Array of runtimes.
    def runtimes
      request(method: :get, path: "/runtimes").map { |data| Runtime.new(data) }
    end

    # Execute code for a given language and version using the added files.
    #
    # @param language [String] Language to use for execution.
    # @param version [String] Version of the language to use for execution.
    # @param stdin [String, nil] Text to pass as stdin to the program.
    # @param args [Array<String>] Arguments to pass to the program.
    # @return [ExecutionResults] Execution results.
    def execute(language:, version:, stdin: nil, args: nil)
      body = {
        language: language,
        version: version,
        files: @files,
        stdin: stdin,
        args: args,
        compile_timeout: @compile_timeout,
        run_timeout: @run_timeout,
        compile_cpu_time: @compile_cpu_time,
        run_cpu_time: @run_cpu_time,
        compile_memory_limit: @compile_memory_limit,
        run_memory_limit: @run_memory_limit
      }.compact

      ExecutionResults.new(request(method: :post, path: "/execute", body: body))
    end

    private :request
  end
end
