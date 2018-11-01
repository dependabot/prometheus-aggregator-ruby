# frozen_string_literal: true

module PrometheusAggregator
  class RackMiddleware
    def initialize(app, options = {})
      @app = app
      @client = options[:client]
      raise ArgumentError, ":client option is required" unless @client
    end

    def call(env)
      start_time = Time.now
      response = @app.call(env)
      duration = Time.now - start_time

      @client.counter(
        name: "http_server_requests_total",
        help: "The total number of HTTP requests handled by the Rack app",
        value: 1,
        labels: labels(env).merge(code: response.first.to_s)
      )

      @client.histogram(
        name: "http_server_request_duration_seconds",
        help: "The HTTP response duration of the Rack application",
        value: duration,
        labels: labels(env)
      )

      response
    end

    def labels(env)
      {
        method: env["REQUEST_METHOD"].downcase,
        path: clean_path(env["PATH_INFO"])
      }
    end

    def clean_path(path)
      path.gsub(%r{/\d+/}, "/:id/").gsub(%r{/\d+$}, "/:id")
    end
  end
end
