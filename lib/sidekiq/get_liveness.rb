# frozen_string_literal: true

require "sidekiq"
require_relative "./get_liveness/version"

module Sidekiq
  HOSTNAME = Socket.gethostname
  PID = Process.pid
  DEFAULT_PATH = ENV.fetch("SIDEKIQ_GET_LIVENESS_URL", "/sidekiq/liveness")
  DEFAULT_PORT = ENV.fetch("SIDEKIQ_GET_LIVENESS_PORT", 8080)

  module GetLiveness
    class << self
      def start_web_server(path: DEFAULT_PATH, port: DEFAULT_PORT)
        Thread.new do
          server = TCPServer.new("localhost", port)
          loop do
            client = server.accept
            request = client.gets

            handle_request(client, request, path)
            client.close
          end
        end
      end

      def handle_request(client, request, path)
        if request.present? && request.start_with?("GET #{path}")
          liveness_check(client)
        else
          client.puts "HTTP/1.1 404 Not Found"
          client.puts "Content-Type: text/plain"
          client.puts
          client.puts "Not Found"
        end
      end

      def liveness_check(client)
        process = Sidekiq::ProcessSet.new.detect do |p|
          p["hostname"] == HOSTNAME && p["pid"] == PID
        end

        if process.present?
          client.puts "HTTP/1.1 200 OK"
          client.puts "Content-Type: text/plain"
          client.puts
          client.puts "Sidekiq Worker #{HOSTNAME}-#{PID} is alive."
        else
          client.puts "HTTP/1.1 503 Service Unavailable"
          client.puts "Content-Type: text/plain"
          client.puts
          client.puts "Sidekiq Worker #{HOSTNAME}-#{PID} is not alive."
        end
      end
    end
  end
end
