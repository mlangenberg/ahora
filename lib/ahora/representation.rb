require 'nibbler'
require 'nokogiri'
require 'time'
require 'date'
require 'delegate'

module Ahora
  class Representation < Nibbler
    present = lambda { |obj| obj && !obj.empty? }

    INTEGER_PARSER = lambda { |node| Integer(node.content) if present.call(node.content) }
    FLOAT_PARSER = lambda { |node| Float(node.content) if present.call(node.content) }
    DATE_PARSER = lambda { |node| Date.parse(node.content) if present.call(node.content) }
    TIME_PARSER = lambda { |node| Time.parse(node.content) if present.call(node.content) }
    BOOL_PARSER = lambda { |node| node.content.to_s.downcase == 'true' }

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
          if Hash === name
            selector, name = name.first
          else
            selector = attribute_selector(name)
          end
          element selector => name.to_s, :with => parser
        end
      end

      # override in subclasses for e.g. camelCase support
      def attribute_selector(name)
        name.to_s
      end

      def string(*names)
        attribute(names)
      end

      def integer(*names)
        attribute(names, INTEGER_PARSER)
      end

      def float(*names)
        attribute(names, FLOAT_PARSER)
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

      # allows using block sub-parsers without explicitly stating they need to
      # inherit from Ahora::Representation
      def base_parser_class
        Representation
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
        doc = doc_or_atts
        doc = XmlParser.parse(doc) unless doc.respond_to?(:search)
        if doc.node_type == Nokogiri::XML::Node::DOCUMENT_NODE
          # immediately scope to root element
          doc = doc.at('/*')
        end
        super(doc)
      end
    end
  end

  module Collection
    class << self
      def instantiate(instantiator, document_parser, response)
        document_parser.call(response.body).search("/*[@type='array']/*").map { |element|
          instantiator.call element
        }.to_a.compact
      end

      # return simple Array object instead of proxy
      alias :new :instantiate
    end
  end

  class XmlParser
    def self.parse(body)
      Nokogiri::XML.parse(body, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
    end
  end
end
