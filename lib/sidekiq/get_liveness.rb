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
          client.puts "Content-Length: #{"Not found".bytesize + 1}"
          client.puts "Content-Type: text/plain"
          client.puts
          client.puts "Not found"
        end
      end

      def liveness_check(client, hostname, pid)
        process = Sidekiq::ProcessSet.new.detect do |p|
          p["hostname"] == hostname && p["pid"] == pid
        end

        message = if process.present?
                    client.puts "HTTP/1.1 200 OK"
                    "Sidekiq Worker #{hostname}-#{pid} is alive."
                  else
                    client.puts "HTTP/1.1 503 Service Unavailable"
                    "Sidekiq Worker #{hostname}-#{pid} is not alive."
                  end

        client.puts "Content-Length: #{message.bytesize + 1}"
        client.puts "Content-Type: text/plain"
        client.puts
        client.puts message
      end
    end
  end
end
