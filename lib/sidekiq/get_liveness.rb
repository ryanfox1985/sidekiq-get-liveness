# frozen_string_literal: true

require "securerandom"
require "sidekiq"

require_relative "./get_liveness/version"
require_relative "./get_liveness/middlewares/server"

module Sidekiq
  WORKER_UUID = SecureRandom.uuid

  module GetLiveness
    class << self
      def start_web_server(path = "/sidekiq/liveness", port = 8080)
        Thread.new do
          server = TCPServer.new("localhost", port)
          loop do
            client = server.accept
            request = client.gets

            handle_request(client, request, path, WORKER_UUID)
            client.close
          end
        end
      end

      def handle_request(client, request, path, worker_uuid)
        if request.present? && request.start_with?("GET #{path}")
          liveness_check(client, worker_uuid)
        else
          client.puts "HTTP/1.1 404 Not Found"
          client.puts "Content-Type: text/plain"
          client.puts
          client.puts "Not Found"
        end
      end

      def liveness_check(client, worker_uuid)
        workers = Sidekiq::Workers.new

        worker = workers.detect do |_process_id, _thread_id, work|
          work["worker_uuid"] == worker_uuid
        end

        if worker.present?
          client.puts "HTTP/1.1 200 OK"
          client.puts "Content-Type: text/plain"
          client.puts
          client.puts "Sidekiq Worker #{worker_uuid} is alive."
        else
          client.puts "HTTP/1.1 503 Service Unavailable"
          client.puts "Content-Type: text/plain"
          client.puts
          client.puts "Sidekiq Worker #{worker_uuid} is not alive."
        end
      end
    end
  end

  configure_server do |config|
    config.server_middleware do |chain|
      chain.add(Sidekiq::GetLiveness::Middlewares::Server, WORKER_UUID)
    end
  end
end
