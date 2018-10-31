# frozen_string_literal: true

require "json"
require "socket"
require "net_tcp_client"

# TODO: error handling, reconnect on (some) failures

module PrometheusAggregator
  class Client
    DEFAULT_BUCKETS = [0.01, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10].freeze

    def initialize(host, port, tls_cert: nil, tls_key: nil, default_labels: {})
      @host = host
      @port = port
      @tls_cert = tls_cert
      @tls_key = tls_key
      @default_labels = default_labels
      @registered = {}
    end

    def counter(name:, value:, help:, labels: {})
      register(name, "counter", help)
      emit_value(name, value, labels)
    end

    def histogram(name:, value:, help:, buckets: DEFAULT_BUCKETS, labels: {})
      register(name, "histogram", help, buckets: buckets)
      emit_value(name, value, labels)
    end

    def disconnect
      socket.close
    end

    private

    def socket
      # TODO: and close?
      @socket = nil if Process.pid != @pid
      return @socket unless @socket.nil?

      @pid = Process.pid
      @registered = {}
      @socket = connect
    #rescue Errno::ECONNREFUSED => err
    #  puts "err #{err}"
    #  sleep 1
    #  retry
    end

    def connect
      ssl_opts = nil
      if @tls_cert && @tls_key
        ssl_opts = {
          cert: OpenSSL::X509::Certificate.new(@tls_cert),
          key: OpenSSL::PKey::RSA.new(@tls_key, ""),
          verify_mode: OpenSSL::SSL::VERIFY_NONE
        }
      end

      Net::TCPClient.new(
        server: "#{@host}:#{@port}",
        ssl: ssl_opts,
        connect_timeout: 3.0,
        write_timeout: 3.0,
        read_timeout: 3.0,
        connect_retry_count: 0
      )
    end

    def register(name, type, help, options = {})
      declaration = options.merge(name: name, type: type, help: help)
      json_declaration = JSON.fast_generate(declaration)
      return if @registered[json_declaration]

      send_line(json_declaration)
      @registered[json_declaration] = true
    end

    def emit_value(name, value, labels)
      labels = labels.merge(@default_labels)
      send_line(JSON.fast_generate(name: name, value: value, labels: labels))
    end

    def send_line(line)
      @socket = nil unless socket.alive?
      socket.write(line + "\n")
    rescue Net::TCPClient::ConnectionFailure
      @socket = nil
    end
  end
end
