# frozen_string_literal: true

require "logger"
require "prometheus_aggregator/version"

module PrometheusAggregator
  class << self
    attr_accessor :logger
  end

  @logger = Logger.new(STDOUT)
end
