# frozen_string_literal: true

module Asciidoctor
  module PDF
    class IndexCatalog
      include ::Asciidoctor::PDF::TextTransformer

      LeadingAlphaRx = /^\p{Alpha}/

      attr_accessor :start_page_number

      def initialize
        @categories = {}
        @start_page_number = 1
        @dests = {}
        @sequence = 0
      end

      def next_anchor_name
        %(__indexterm-#{@sequence += 1})
      end

      def store_term names, dest = nil
        if (num_terms = names.size) > 2
          store_tertiary_term names[0], names[1], names[2], dest
        elsif num_terms == 2
          store_secondary_term names[0], names[1], dest
        elsif num_terms == 1
          store_primary_term names[0], dest
        end
      end

      def store_primary_term name, dest = nil
        store_dest dest if dest
        (init_category uppercase_mb name.chr).store_term name, dest
      end

      def store_secondary_term primary_name, secondary_name, dest = nil
        store_dest dest if dest
        (store_primary_term primary_name).store_term secondary_name, dest
      end

      def store_tertiary_term primary_name, secondary_name, tertiary_name, dest = nil
        store_dest dest if dest
        (store_secondary_term primary_name, secondary_name).store_term tertiary_name, dest
      end

      def init_category name
        name = '@' unless LeadingAlphaRx.match? name
        @categories[name] ||= IndexTermCategory.new name
      end

      def find_category name
        @categories[name]
      end

      def store_dest dest
        @dests[dest[:anchor]] = dest
      end

      def link_dest_to_page anchor, physical_page_number
        if (dest = @dests[anchor])
          virtual_page_number = physical_page_number - (@start_page_number - 1)
          dest[:page] = (virtual_page_number < 1 ? (RomanNumeral.new physical_page_number, :lower) : virtual_page_number).to_s
        end
      end

      def empty?
        @categories.empty?
      end

      def categories
        @categories.empty? ? [] : @categories.values.sort
      end
    end

    class IndexTermGroup
      include Comparable
      attr_reader :name

      def initialize name
        @name = name
        @terms = {}
      end

      def store_term name, dest = nil
        term = (@terms[name] ||= (IndexTerm.new name))
        term.add_dest dest if dest
        term
      end

      def find_term name
        @terms[name]
      end

      def terms
        @terms.empty? ? [] : @terms.values.sort
      end

      def <=> other
        (val = @name.casecmp other.name) == 0 ? @name <=> other.name : val
      end
    end

    class IndexTermCategory < IndexTermGroup; end

    class IndexTerm < IndexTermGroup
      def initialize name
        super
        @dests = ::Set.new
      end

      alias subterms terms

      def add_dest dest
        @dests << dest
        self
      end

      def dests
        @dests.select {|d| d.key? :page }.sort {|a, b| a[:page] <=> b[:page] }
      end

      def container?
        @dests.empty? || @dests.none? {|d| d.key? :page }
      end

      def leaf?
        @terms.empty?
      end
    end
  end
end
