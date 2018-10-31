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

    response = Excon.get("http://localhost:8192/metrics")
    assert_includes response.body, "# HELP test_counter Help text\n"
    assert_includes response.body, "# TYPE test_counter counter\n"
    assert_includes response.body, "test_counter{} 2.0"
  end

  def test_histograms_work_correctly
    client = AggregatorServer.client
    client.histogram(name: "test_histogram", value: 0.9, help: "Help text")

    response = Excon.get("http://localhost:8192/metrics")
    assert_includes response.body, "# HELP test_histogram Help text\n"
    assert_includes response.body, "# TYPE test_histogram histogram\n"
    assert_includes response.body, "test_histogram_bucket{le=\"0.01\"} 0\n"
    assert_includes response.body, "test_histogram_bucket{le=\"1\"} 1\n"
  end

  def test_handles_disconnections
    client = AggregatorServer.client

    client.counter(name: "test_counter_1", value: 1, help: "Help text")

    AggregatorServer.stop

    # Shouldn't blow up
    client.counter(name: "test_counter_1", value: 1, help: "Help text")
  end

  def test_handles_reconnections
    client = AggregatorServer.client

    client.counter(name: "test_counter_1", value: 1, help: "Help text")

    AggregatorServer.stop
    AggregatorServer.start

    client.counter(name: "test_counter_2", value: 1, help: "Help text")
    sleep 0.1

    response = Excon.get("http://localhost:8192/metrics")
    assert_includes response.body, "test_counter_2{} 1.0"
  end
end
