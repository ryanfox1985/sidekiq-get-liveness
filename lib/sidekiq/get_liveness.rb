# frozen_string_literal: true

require "connection_pool"
require "redis"
require "sidekiq"
require_relative "./get_liveness/version"

module Sidekiq
  DEFAULT_PATH = ENV.fetch("SIDEKIQ_GET_LIVENESS_URL", "/sidekiq/liveness")
  DEFAULT_PORT = ENV.fetch("SIDEKIQ_GET_LIVENESS_PORT", 8080)
  REDIS_POOL = ConnectionPool.new(size: 5, timeout: 5) { Redis.new }

  module GetLiveness
    class << self
      def start_web_server(path: DEFAULT_PATH,
                           port: DEFAULT_PORT,
                           hostname: ::Socket.gethostname,
                           pid: ::Process.pid)
        Thread.new do
          server = TCPServer.new("0.0.0.0", port)
          loop do
            client = server.accept
            request = client.gets

            response = handle_request(request, path, hostname, pid)
            client.puts "#{response.join("\r\n")}\r\n"
            client.close
          end
        end
      end

      def handle_request(request, path, hostname, pid)
        if request.present? && request.start_with?("GET #{path}")
          liveness_check(hostname, pid)
        else
          message = "Not found"
          [
            "HTTP/1.1 404 Not Found",
            "Content-Length: #{message.bytesize + 2}",
            "Content-Type: text/plain",
            "Date: #{Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT")}",
            "",
            message
          ]
        end
      end

      def liveness_check(hostname, pid)
        process = Sidekiq::ProcessSet.new.detect do |p|
          p["hostname"] == hostname && p["pid"] == pid
        end

        if process.present?
          message = "Sidekiq Worker #{hostname}-#{pid} is alive."
          [
            "HTTP/1.1 200 OK",
            "Content-Length: #{message.bytesize + 2}",
            "Content-Type: text/plain",
            "Date: #{Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT")}",
            "",
            message
          ]
        else
          message = "Sidekiq Worker #{hostname}-#{pid} is not alive."
          [
            "HTTP/1.1 503 Service Unavailable",
            "Content-Length: #{message.bytesize + 2}",
            "Content-Type: text/plain",
            "Date: #{Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT")}",
            "",
            message
          ]
        end
      end
    end
  end
end
