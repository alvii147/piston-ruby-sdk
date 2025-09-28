# typed: true
# frozen_string_literal: true

require "net/http"
require "json"
require "sorbet-runtime"
require_relative "piston_sdk/version"

# A minimal Ruby gem for using the [Piston API](https://github.com/engineer-man/piston).
module PistonSDK
  # Data representation of a Piston runtime.
  class Runtime
    extend T::Sig

    sig { returns(String) }
    attr_reader :language

    sig { returns(String) }
    attr_reader :version

    sig { returns(T::Array[String]) }
    attr_reader :aliases

    sig { returns(T.nilable(String)) }
    attr_reader :runtime

    # Create a new Piston runtime.
    #
    # @param data [Hash] JSON data
    sig { params(data: T::Hash[String, T.untyped]).void }
    def initialize(data)
      @language = T.let(data["language"], String)
      @version = T.let(data["version"], String)
      @aliases = T.let(data["aliases"], T::Array[String])
      @runtime = T.let(data["runtime"], T.nilable(String))
    end
  end

  # Data representation of Piston execution step details.
  class ExecutionStepDetails
    extend T::Sig

    sig { returns(String) }
    attr_reader :stdout

    sig { returns(String) }
    attr_reader :stderr

    sig { returns(String) }
    attr_reader :output

    sig { returns(T.nilable(Integer)) }
    attr_reader :code

    sig { returns(T.nilable(String)) }
    attr_reader :signal

    sig { returns(T.nilable(String)) }
    attr_reader :message

    sig { returns(T.nilable(String)) }
    attr_reader :status

    sig { returns(T.nilable(Integer)) }
    attr_reader :cpu_time

    sig { returns(T.nilable(Integer)) }
    attr_reader :wall_time

    sig { returns(T.nilable(Integer)) }
    attr_reader :memory

    # Create new Piston execution step details.
    #
    # @param data [Hash] JSON data
    sig { params(data: T::Hash[String, T.untyped]).void }
    def initialize(data)
      @stdout = T.let(data["stdout"], String)
      @stderr = T.let(data["stderr"], String)
      @output = T.let(data["output"], String)
      @code = T.let(data["code"], T.nilable(Integer))
      @signal = T.let(data["signal"], T.nilable(String))
      @message = T.let(data["message"], T.nilable(String))
      @status = T.let(data["status"], T.nilable(String))
      @cpu_time = T.let(data["cpu_time"], T.nilable(Integer))
      @wall_time = T.let(data["wall_time"], T.nilable(Integer))
      @memory = T.let(data["memory"], T.nilable(Integer))
    end
  end

  # Data representation of Piston execution results.
  class ExecutionResults
    extend T::Sig

    sig { returns(String) }
    attr_reader :language

    sig { returns(String) }
    attr_reader :version

    sig { returns(ExecutionStepDetails) }
    attr_reader :run

    sig { returns(T.nilable(ExecutionStepDetails)) }
    attr_reader :compile

    # Create new Piston execution results.
    #
    # @param data [Hash] JSON data
    sig { params(data: T::Hash[String, T.untyped]).void }
    def initialize(data)
      @language = T.let(data["language"], String)
      @version = T.let(data["version"], String)
      @run = T.let(ExecutionStepDetails.new(data["run"]), ExecutionStepDetails)
      @compile = T.let(
        data["compile"] ? ExecutionStepDetails.new(data["compile"]) : nil,
        T.nilable(ExecutionStepDetails)
      )
    end
  end

  # HTTP client for the Piston API.
  class Client
    extend T::Sig

    # Create a new client.
    #
    # @param base_url [String] Base URL for API
    # @param retries [Integer] Number of automatic retries to perform when rate limit is reached
    # @param compile_timeout [Integer, nil] The maximum wall-time allowed for the compile stage to finish before bailing
    # out in milliseconds
    # @param run_timeout [Integer, nil] The maximum wall-time allowed for the run stage to finish before bailing out in
    # milliseconds
    # @param compile_cpu_time [Integer, nil] The maximum CPU-time allowed for the compile stage to finish before bailing
    # out in milliseconds
    # @param run_cpu_time [Integer, nil] The maximum CPU-time allowed for the run stage to finish before bailing out in
    # milliseconds
    # @param compile_memory_limit [Integer, nil] The maximum amount of memory the compile stage is allowed to use in
    # bytes
    # @param run_memory_limit [Integer, nil] The maximum amount of memory the run stage is allowed to use in bytes
    sig do
      params(
        base_url: String,
        retries: Integer,
        compile_timeout: T.nilable(Integer),
        run_timeout: T.nilable(Integer),
        compile_cpu_time: T.nilable(Integer),
        run_cpu_time: T.nilable(Integer),
        compile_memory_limit: T.nilable(Integer),
        run_memory_limit: T.nilable(Integer)
      ).void
    end
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
      @uri = T.let(URI(base_url), URI::Generic)
      @retries = T.let(retries, Integer)
      @compile_timeout = T.let(compile_timeout, T.nilable(Integer))
      @run_timeout = T.let(run_timeout, T.nilable(Integer))
      @compile_cpu_time = T.let(compile_cpu_time, T.nilable(Integer))
      @run_cpu_time = T.let(run_cpu_time, T.nilable(Integer))
      @compile_memory_limit = T.let(compile_memory_limit, T.nilable(Integer))
      @run_memory_limit = T.let(run_memory_limit, T.nilable(Integer))
      @files = T.let([], T::Array[T::Hash[Symbol, String]])

      @http = T.let(Net::HTTP.new(@uri.host, @uri.port), Net::HTTP)
      @http.use_ssl = true

      @method_classes = T.let(
        {
          get: Net::HTTP::Get,
          post: Net::HTTP::Post
        },
        T::Hash[Symbol, T.class_of(Net::HTTPRequest)]
      )
    end

    # Perform raw HTTP request using exponential backoff on retries.
    #
    # @param method [Symbol] HTTP method
    # @param path [String] URL Path
    # @param body [Hash, nil] Optional request body
    # @return [Hash, Array] JSON response
    sig do
      params(
        method: Symbol,
        path: String,
        body: T.nilable(T::Hash[Symbol, T.untyped])
      ).returns(
        T.any(
          T::Hash[T.untyped, T.untyped],
          T::Array[T.untyped]
        )
      )
    end
    def request(method: :get, path: "", body: nil)
      req = T.must(@method_classes[method]).new("#{@uri}#{path}")
      req["Content-Type"] = "application/json"
      req.body = body.to_json unless body.nil?
      res = @http.request(req)

      (0...@retries).each do |attempt|
        res = @http.request(req)

        case res
        when Net::HTTPOK
          return JSON.parse(res.body || "{}")
        when Net::HTTPTooManyRequests
          sleep 2**attempt
        else
          raise "Request failed with status code #{res.code}, #{res.body}"
        end
      end

      raise "Request failed due to rate limits after too many attempts"
    end

    # Add file to be sent to Piston for execution.
    #
    # @param content [String] Content of the files to upload
    # @param name [String, nil] Name of the file to upload
    # @param encoding [String, nil] Encoding scheme used for the file content
    sig do
      params(
        content: String,
        name: T.nilable(String),
        encoding: T.nilable(String)
      ).void
    end
    def add_file(content:, name: nil, encoding: nil)
      file = {
        name: name,
        content: content,
        encoding: encoding
      }.compact

      @files << file
    end

    # Clear all files
    sig { void }
    def clear_files
      @files.clear
    end

    # Get supported languages along with the current version and aliases.
    #
    # @return [Array<Runtime>] List of supported runtimes
    sig { returns(T::Array[Runtime]) }
    def runtimes
      request(method: :get, path: "/runtimes").map do |data|
        Runtime.new(T.cast(data, T::Hash[String, T.untyped]))
      end
    end

    # Execute code for a given language and version using the added files.
    #
    # @param language [String] Language to use for execution
    # @param version [String] Version of the language to use for execution
    # @param stdin [String, nil] Text to pass as stdin to the program
    # @param args [Array<String>] Arguments to pass to the program
    # @return [ExecutionResults] Execution results
    sig do
      params(
        language: String,
        version: String,
        stdin: T.nilable(String),
        args: T.nilable(T::Array[String])
      ).returns(ExecutionResults)
    end
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

      ExecutionResults.new(
        T.cast(request(method: :post, path: "/execute", body: body), T::Hash[String, T.untyped])
      )
    end

    private :request
  end
end
