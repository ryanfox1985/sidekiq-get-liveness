# frozen_string_literal: true

require "sidekiq"
require_relative "./get_liveness/version"

module Sidekiq
  DEFAULT_PATH = ENV.fetch("SIDEKIQ_GET_LIVENESS_URL", "/sidekiq/liveness")
  DEFAULT_PORT = ENV.fetch("SIDEKIQ_GET_LIVENESS_PORT", 8080)

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

            handle_request(client, request, path, hostname, pid)
            client.close
          end
        end
      end

      def handle_request(client, request, path, hostname, pid)
        if request.present? && request.start_with?("GET #{path}")
          liveness_check(client, hostname, pid)
        else
          client.puts "HTTP/1.1 404 Not Found"
          message = "Not found"
          client.puts "Content-Length: #{message.bytesize + 1}"
          client.puts "Content-Type: text/plain"
          client.puts
          client.puts message
        end
      end

      def liveness_check(client, hostname, pid)
        process = Sidekiq::ProcessSet.new.detect do |p|
          p["hostname"] == hostname && p["pid"] == pid
        end

        if process.present?
          client.puts "HTTP/1.1 200 OK"
          client.puts "Content-Length: 0"
          client.puts "Content-Type: text/plain"
          client.puts "Connection: keep-alive"
          client.puts "Date: #{Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT")}"
          client.puts
        else
          client.puts "HTTP/1.1 503 Service Unavailable"
          message = "Sidekiq Worker #{hostname}-#{pid} is not alive."
          client.puts "Content-Length: #{message.bytesize + 1}"
          client.puts "Content-Type: text/plain"
          client.puts
          client.puts message
        end
      end
    end
  end
end
