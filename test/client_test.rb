# frozen_string_literal: true

require "excon"
require "test_helper"
require "prometheus_aggregator/client"

class ClientTest < Minitest::Test
  def setup
    AggregatorServer.start
  end

  def teardown
    AggregatorServer.stop
  end

  def test_counters_work_correctly
    client = AggregatorServer.client
    client.counter(name: "test_counter", value: 1, help: "Help text")
    client.counter(name: "test_counter", value: 1, help: "Help text")
    sleep 0.1

    scrape_result = AggregatorServer.scrape_metrics
    assert_includes scrape_result, "# HELP test_counter Help text\n"
    assert_includes scrape_result, "# TYPE test_counter counter\n"
    assert_includes scrape_result, "test_counter{} 2.0"

    client.stop
  end

  def test_histograms_work_correctly
    client = AggregatorServer.client
    client.histogram(name: "test_histogram", value: 0.9, help: "Help text")
    sleep 0.1

    scrape_result = AggregatorServer.scrape_metrics
    assert_includes scrape_result, "# HELP test_histogram Help text\n"
    assert_includes scrape_result, "# TYPE test_histogram histogram\n"
    assert_includes scrape_result, "test_histogram_bucket{le=\"0.01\"} 0\n"
    assert_includes scrape_result, "test_histogram_bucket{le=\"1\"} 1\n"

    client.stop
  end

  def test_handles_disconnections
    client = AggregatorServer.client

    client.counter(name: "test_counter_1", value: 1, help: "Help text")

    AggregatorServer.stop

    # Shouldn't blow up
    client.counter(name: "test_counter_1", value: 1, help: "Help text")

    client.stop
  end

  def test_handles_reconnections
    client = AggregatorServer.client

    client.counter(name: "test_counter_1", value: 1, help: "Help text")

    AggregatorServer.stop
    AggregatorServer.start

    # Connection retries happen every second
    sleep 1.2
    client.counter(name: "test_counter_2", value: 1, help: "Help text")
    sleep 0.1

    assert_includes AggregatorServer.scrape_metrics, "test_counter_2{} 1.0"

    client.stop
  end
end
