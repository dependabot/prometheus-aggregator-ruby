# frozen_string_literal: true

require "faraday"
require "prometheus_aggregator"

module PrometheusAggregator
  class FaradayMiddleware < Faraday::Middleware
    def initialize(app, options = {})
      super(app)
      @client = options[:client]
      raise ArgumentError, ":client option is required" unless @client
    end

    def call(request_env)
      start_time = Time.now
      @app.call(request_env).on_complete do |response_env|
        duration = Time.now - start_time
        status_code = response_env[:status].to_s

        begin
          @client.counter(
            name: "http_client_requests_total",
            help: "The total number of HTTP requests sent by the client",
            value: 1,
            labels: labels(response_env).merge(code: status_code)
          )

          @client.histogram(
            name: "http_client_request_duration_seconds",
            help: "The HTTP response duration",
            value: duration,
            labels: labels(response_env)
          )
        rescue => err # rubocop:disable Style/RescueStandardError
          # Let's be ultra defensive. Metrics should never break the app.
          PrometheusAggregator.logger.error("FaradayMiddleware: #{err}")
        end
      end
    end

    private

    def labels(response_env)
      {
        method: response_env[:method].to_s,
        host: response_env[:url].host
      }
    end
  end
end
