# frozen_string_literal: true

require "rack"
require "test_helper"
require "prometheus_aggregator/rack_middleware"

class RackMiddlewareTest < Minitest::Test
  def app
    ->(env) { [200, env, "Hello!"] }
  end

  def env_for(url, opts = {})
    Rack::MockRequest.env_for(url, opts)
  end

  def test_the_app_still_works
    client = Minitest::Mock.new
    client.expect(:counter, nil, [Hash])
    client.expect(:histogram, nil, [Hash])

    middleware = PrometheusAggregator::RackMiddleware.new(app, client: client)
    code, = middleware.call(env_for("https://example.com/foo"))

    assert_equal 200, code
  end

  def test_reports_request_metrics
    client = Minitest::Mock.new

    client.expect(:counter, nil) do |opts|
      next false unless opts[:labels][:method] == "get"
      next false unless opts[:labels][:path] == "/foo/:id/bar/:id"
      next false unless opts[:labels][:code] == "200"

      opts[:value] == 1
    end

    client.expect(:histogram, nil) do |opts|
      next false unless opts[:labels][:method] == "get"
      next false unless opts[:labels][:path] == "/foo/:id/bar/:id"

      opts[:value] > 0.0 && opts[:value] < 0.01
    end

    middleware = PrometheusAggregator::RackMiddleware.new(app, client: client)
    middleware.call(env_for("https://example.com/foo/123/bar/456"))

    client.verify
  end
end
