require 'nibbler'
require 'nokogiri'
require 'date'
require 'active_support/core_ext/string'


module Ahora
  class Representation < Nibbler
    INTEGER_PARSER = lambda { |node| Integer(node.content) if node.content.present? }
    DATE_PARSER = lambda { |node| Date.parse(node.content) if node.content.present? }

    def self.doc(response)
       Nokogiri::XML.parse(response.body, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
    end

    def self.collection(response)
      doc(response).search("/*[@type='array']/*").map do |element|
        member element
      end
    end

    def self.member(document)
      self.parse(document)
    end

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
    end

    extend Definition
  end
end