# frozen_string_literal: true

require "test_helper"
require "prometheus_aggregator/client"

class ClientTest < Minitest::Test
  def test_capacity_is_enforced
    exporter = PrometheusAggregator::Exporter.new(nil, nil)
    105.times { exporter.enqueue(:foo) }

    capacity = PrometheusAggregator::Exporter::QUEUE_CAPACITY
    assert_equal capacity, exporter.backlog
  end
end
