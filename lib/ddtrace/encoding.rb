require 'json'
require 'msgpack'

module Datadog
  # Encoding module that encodes data for the AgentTransport
  module Encoding
    # Encoder interface that provides the logic to encode traces and service
    class Encoder
      attr_reader :content_type

      # When extending the ``Encoder`` class, ``content_type`` must be set because
      # they're used by the HTTPTransport so that it should not need to know what is
      # the right header to suggest the decoding format to the agent
      def initialize
        @content_type = ''
      end

      # Encodes a list of traces, expecting a list of items where each items
      # is a list of spans. Before dump the string in a serialized format all
      # traces are normalized. The traces nesting is not changed.
      def encode_traces(traces)
        # to_send = []
        # traces.each do |trace|
        #   to_send << trace.map(&:to_hash)
        # end
        to_send = traces
        encode(to_send)
      end

      # Encodes services hash
      def encode_services(services)
        encode(services)
      end

      # Defines the underlying format used during traces or services encoding.
      # This method must be implemented and should only be used by the internal functions.
      def encode(_)
        raise NotImplementedError
      end
    end

    # Encoder for the JSON format
    class JSONEncoder < Encoder
      def initialize
        Datadog::Tracer.log.debug('using JSON encoder; application performance may be degraded')
        @content_type = 'application/json'
      end

      def encode(obj)
        data = obj.map { |a| a.map(&:to_hash) }
        JSON.dump(data)
      end
    end

    # Encoder for the Msgpack format
    class MsgpackEncoder < Encoder
      def initialize
        Datadog::Tracer.log.debug('using Msgpack encoder')
        @content_type = 'application/msgpack'

        @packer = MessagePack::Packer.new
      end

      def encode(obj)
        @packer.clear
        @packer.write_array_header(obj.length)
        obj.each do |array|
          @packer.write_array_header(array.length)
          array.each do |elem|
            if elem.respond_to?(:pack_msgpack)
              elem.pack_msgpack(@packer)
            else
              @packer.pack(elem)
            end
          end
        end
        @packer.to_s
      end
    end
  end
end
