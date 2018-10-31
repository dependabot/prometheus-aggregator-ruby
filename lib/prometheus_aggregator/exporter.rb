# frozen_string_literal: true

require "openssl"
require "json"
require "socket"
require "net_tcp_client"
require "prometheus_aggregator"

module PrometheusAggregator
  class Exporter
    CONNECTION_RETRY_INTERVAL = 1.0
    QUEUE_CAPACITY = 100
    LOOP_INTERVAL = 0.01
    STALENESS_THRESHOLD = 5.0

    def initialize(host, port, opts = {})
      @host = host
      @port = port
      @ssl_params = opts[:ssl_params]
      @staleness_threshold = opts[:staleness_threshold] || STALENESS_THRESHOLD
      @connection_retry_interval =
        opts[:connection_retry_interval] || CONNECTION_RETRY_INTERVAL
      @registered = {}

      @mutex = Mutex.new
      @queue = []
    end

    def start
      @stop = false
      @thread = Thread.new { write_loop }
    end

    def enqueue(record)
      @mutex.synchronize do
        @queue << [Time.now, record]
        @queue.shift while @queue.length > QUEUE_CAPACITY
      end
    end

    def backlog
      @queue.length
    end

    def stop
      @stop = true
    end

    private

    def write_loop
      loop do
        break if @stop

        connect unless connection_ok?
        unless connection_ok?
          PrometheusAggregator.logger.warn(
            "Not connected to prometheus agggregator (#{@host}:#{@port})"
          )

          sleep(@connection_retry_interval)
          next
        end

        event = @mutex.synchronize do
          @queue.shift while !@queue.empty? && stale?(@queue.first)
          @queue.shift
        end

        if event.nil?
          sleep(LOOP_INTERVAL)
          next
        end

        record = event[1]
        register(record)
        emit_value(record)
      end
    end

    def stale?(record)
      record[0] < Time.now - @staleness_threshold
    end

    def connection_ok?
      return false unless @socket
      return false if Process.pid != @pid

      @socket.alive?
    end

    def connect
      @registered = {}
      @pid = Process.pid

      @socket = Net::TCPClient.new(
        server: "#{@host}:#{@port}",
        ssl: @ssl_params,
        connect_timeout: 3.0,
        write_timeout: 3.0,
        read_timeout: 3.0,
        connect_retry_count: 0
      )
    rescue Net::TCPClient::ConnectionFailure => err
      PrometheusAggregator.logger.debug(err)
      @socket = nil
    end

    def register(record)
      declaration = record.reject { |k| k == :value }
      json_declaration = JSON.fast_generate(declaration)
      return if @registered[json_declaration]

      send_line(json_declaration)
      @registered[json_declaration] = true
    end

    def emit_value(record)
      send_line(JSON.fast_generate(record.slice(:name, :value, :labels)))
    end

    def send_line(line)
      @socket.write(line + "\n")
    rescue Net::TCPClient::ConnectionFailure => err
      PrometheusAggregator.logger.debug(err)
      @socket = nil
    end
  end
end
