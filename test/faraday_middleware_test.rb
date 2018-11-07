# frozen_string_literal: true

require "faraday"
require "test_helper"
require "prometheus_aggregator/faraday_middleware"

class FaradayMiddlewareTest < Minitest::Test
  def stubbed_faraday(client)
    Faraday.new do |f|
      f.use PrometheusAggregator::FaradayMiddleware, client: client
      f.adapter :test do |stub|
        stub.get "/" do
          [200, {}, "ok"]
        end
      end
    end
  end

  def test_the_request_still_works
    client = Minitest::Mock.new
    client.expect(:counter, nil, [Hash])
    client.expect(:histogram, nil, [Hash])

    faraday = stubbed_faraday(client)
    response = faraday.get("https://example.com/")

    assert_equal 200, response.status
  end

  def test_reports_request_metrics
    client = Minitest::Mock.new

    client.expect(:counter, nil) do |opts|
      next false unless opts[:labels][:method] == "get"
      next false unless opts[:labels][:host] == "example.com"
      next false unless opts[:labels][:code] == "200"

      opts[:value] == 1
    end

    client.expect(:histogram, nil) do |opts|
      next false unless opts[:labels][:method] == "get"
      next false unless opts[:labels][:host] == "example.com"

      opts[:value] > 0.0 && opts[:value] < 0.01
    end

    faraday = stubbed_faraday(client)
    faraday.get("https://example.com/")

    client.verify
  end
end
