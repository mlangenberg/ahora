require 'nibbler'
require 'nokogiri'
require 'date'
require 'active_support/core_ext/string'
require 'delegate'

module Ahora
  # TODO move parse bits to a instantiable class
  class Representation < Nibbler
    INTEGER_PARSER = lambda { |node| Integer(node.content) if node.content.present? }
    DATE_PARSER = lambda { |node| Date.parse(node.content) if node.content.present? }

    module Definition
      def attribute(*names)
        names = names.flatten
        parser = names.pop if names.last.is_a?(Proc)
        names.each do |name|
          selector = name
          if name.is_a? Hash
            selector, name = name.first
          end
          element selector.to_s.camelcase(:lower) => name.to_s, :with => parser
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
      # element 'parentObjectId' => 'parent_id'`az
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
    attr_reader :cache_key
    def initialize(klass, document_parser, response)
      @klass = klass
      @document_parser = document_parser
      @response = response
      @cache_key = response.env[:url].to_s
      super([])
    end

    def size
      kicker
      super
    end

    def each(*)
      kicker
      super
    end

    def first
      kicker
      super
    end

    def last
      kicker
      super
    end

    def [](*)
      kicker
      super
    end

    private
    def kicker
      __setobj__ doc.search("/*[@type='array']/*").map { |element|
        @klass.parse element
      }.to_a
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