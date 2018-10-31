# frozen_string_literal: true

require "prometheus_aggregator/exporter"

module PrometheusAggregator
  class Client
    DEFAULT_BUCKETS = [0.01, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10].freeze

    def initialize(host, port, tls_cert: nil, tls_key: nil, default_labels: {})
      @exporter = Exporter.new(host, port, tls_cert, tls_key)
      @default_labels = default_labels

      @exporter.start
    end

    def counter(name:, value:, help:, labels: {})
      @exporter.enqueue(
        type: "counter",
        name: name,
        value: value,
        help: help,
        labels: @default_labels.dup.merge(labels)
      )
    end

    def histogram(name:, value:, help:, buckets: DEFAULT_BUCKETS, labels: {})
      @exporter.enqueue(
        type: "histogram",
        name: name,
        value: value,
        help: help,
        buckets: buckets,
        labels: @default_labels.dup.merge(labels)
      )
    end

    def stop
      @exporter.stop
    end
  end
end
