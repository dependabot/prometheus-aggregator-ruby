# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "prometheus_aggregator"

require "minitest/autorun"
require "excon"

module AggregatorServer
  def self.client
    PrometheusAggregator::Client.new("localhost", 8191)
  end

  def self.start
    download_binary unless File.exist?(binary_path)

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

  def self.binary_path
    File.join(binary_dir, "prometheus-aggregator")
  end

  def self.binary_dir
    File.join(File.expand_path("..", __dir__), "tmp")
  end

  def self.download_binary
    puts " => Downloading prometheus-aggregator binary"
    repo = "peterbourgon/prometheus-aggregator"
    releases_url = "https://api.github.com/repos/#{repo}/releases/latest"
    response = JSON.parse(Excon.get(releases_url).body)
    asset = response["assets"].find { |a| a["name"].include?(platform) }

    download_url = Excon.get(asset["browser_download_url"]).headers["Location"]
    response = Excon.get(download_url, omit_default_port: true)
    FileUtils.mkdir_p(binary_dir)
    File.open(binary_path, "wb", 0o755) { |f| f.write(response.body) }
  end

  def self.platform
    case RbConfig::CONFIG["arch"]
    when /linux/ then "linux"
    when /darwin/ then "darwin"
    else raise "Invalid platform #{RbConfig::CONFIG['arch']}"
    end
  end
end
