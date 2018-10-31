# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "prometheus_aggregator"

require "minitest/autorun"

module AggregatorServer
  def self.client
    PrometheusAggregator::Client.new("localhost", 8191)
  end

  def self.start
    binary_name = "prometheus-aggregator-0.0.11-darwin-amd64"
    binary_path = File.join(File.expand_path("..", __dir__), binary_name)
    @pid = IO.popen(binary_path).pid

    wait_for_server
  end

  def self.stop(signal: :SIGTERM)
    start_time = Time.now

    begin
      Process.kill(signal, @pid)

      loop do
        sleep 0.1
        Process.getpgid(@pid)
        break if Time.now > start_time + 2.0
      end
    rescue Errno::ESRCH
      # Process is dead
      return
    end

    stop(:SIGKILL)
  end

  def self.wait_for_server
    retries = 0
    begin
      socket = TCPSocket.new("localhost", 8191)
      socket.close
    rescue Errno::ECONNREFUSED => err
      raise err if retries >= 20

      sleep 0.1
      retries += 1
      retry
    end
  end
end
