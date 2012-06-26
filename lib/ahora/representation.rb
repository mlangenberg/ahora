require 'nibbler'
require 'nokogiri'
require 'date'
require 'active_support/core_ext/string'
require 'delegate'

module Ahora
  class Representation < Nibbler
    INTEGER_PARSER = lambda { |node| Integer(node.content) if node.content.present? }
    DATE_PARSER = lambda { |node| Date.parse(node.content) if node.content.present? }
    TIME_PARSER = lambda { |node| Time.parse(node.content) if node.content.present? }
    BOOL_PARSER =
        lambda { |node| node.content.to_s.downcase == 'true' if node.content.present? }

    module Definition
      def element(*)
        name = super
        define_method "#{name}?" do
          !!instance_variable_get("@#{name}")
        end
        name
      end

      def attribute(*names)
        names = names.flatten
        parser = names.pop if names.last.is_a?(Proc)
        names.each do |name|
          selector = name
          if name.is_a? Hash
            selector, name = name.first
          end
          element to_selector(selector.to_s.camelcase(:lower)) => name.to_s, :with => parser
        end
      end

      # Public: define Java style object id mapping
      #
      # *names - Array of String or Symbol ruby style names
      #
      # Examples
      #
      # objectid :id, parent_id
      # # is equivalent to
      # element 'objectId' => 'id'
      # element 'parentObjectId' => 'parent_id'
      def objectid(*names)
        attribute names.map { |name| { name.to_s.gsub('id', 'object_id') => name } }, INTEGER_PARSER
      end

      def string(*names)
        attribute(names)
      end

      def integer(*names)
        attribute(names, INTEGER_PARSER)
      end

      def date(*names)
        attribute(names, DATE_PARSER)
      end

      # FIXME test
      def time(*names)
        attribute(names, TIME_PARSER)
      end

      def boolean(*names)
        attribute(names, BOOL_PARSER)
      end

      private
      # Convert to XPATH selector for current node or
      # one level deep.
      def to_selector(name)
        "./*/#{name}|./#{name}"
      end
    end

    extend Definition

    def initialize(doc_or_atts = {})
      if doc_or_atts.is_a? Hash
        super(nil)
        doc_or_atts.each do |key, val|
          send("#{key}=", val)
        end
      else
        super
      end
    end
  end

  class Collection < DelegateClass(Array)
    NoCacheKeyAvailable = Class.new(StandardError)
    def initialize(instantiator, document_parser, response)
      @instantiator = instantiator
      @document_parser = document_parser
      @response = response
      @cache_key = response.env[:response_headers]['X-Ahora-Cache-Key']
      super([])
    end

    def cache_key
      @cache_key or raise NoCacheKeyAvailable,
          "No caching middleware is used or resource does not support caching."
    end

    %w( to_s to_a size each first last [] inspect pretty_print ).each do |method_name|
      eval "def #{method_name}(*); kicker; super; end"
    end

    private
    def kicker
      @_collection ||= __setobj__ doc.search("/*[@type='array']/*").map { |element|
        @instantiator.call element
      }.to_a.compact
    end

    def doc
      @document_parser.call(@response.body)
    end
  end

  class XmlParser
    def self.parse(body)
      Nokogiri::XML.parse(body, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
    end
  end
end