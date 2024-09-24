# frozen_string_literal: true

module Sidekiq
  module GetLiveness
    module Middlewares
      class Server
        def initialize(uuid)
          @uuid = uuid
        end

        def call(_worker, msg, _queue)
          puts @uuid
          msg['worker_uuid'] = @uuid
          yield
        end
      end
    end
  end
end
