# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "prometheus_aggregator"

require "minitest/autorun"
require "excon"

module AggregatorServer
  LISTEN_PORT = 18_191
  SCRAPE_PORT = 18_192

  def self.scrape_metrics
    Excon.get("http://127.0.0.1:#{SCRAPE_PORT}/metrics").body
  end

  def self.client(opts = {})
    opts = { connection_retry_interval: 0.1 }.merge(opts)
    PrometheusAggregator::Client.new("127.0.0.1", LISTEN_PORT, opts)
  end

  def self.start
    download_binary unless File.exist?(binary_path)

    listen_addr = "tcp://127.0.0.1:#{LISTEN_PORT}"
    scrape_url = "tcp://127.0.0.1:#{SCRAPE_PORT}/metrics"
    args = ["-socket", listen_addr, "-prometheus", scrape_url]
    @pid = IO.popen(([binary_path] + args).join(" ")).pid

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
      socket = TCPSocket.new("127.0.0.1", LISTEN_PORT)
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
