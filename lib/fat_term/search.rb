# frozen_string_literal: true

module FatTerm
  module Search
    extend self

    # Split query into white-space-separated terms.
    def split_terms(query)
      query.to_s.strip.split(/\s+/).reject(&:empty?)
    end

    # Return the haystack items that match all the space-separated terms in
    # query, regarless of order or case.
    def match_all_terms?(haystack, query)
      terms = split_terms(query)
      return true if terms.empty?

      text = haystack.to_s.downcase
      terms.all? { |term| text.include?(term.downcase) }
    end

    def compile_regexp(pattern, regex: false)
      return Regexp.new(pattern) if regex

      terms = split_terms(pattern)
      flags = pattern.match?(/[[:upper:]]/) ? 0 : Regexp::IGNORECASE
      return Regexp.new("", flags) if terms.empty?

      lookaheads =
        terms.map do |term|
          "(?=.*#{Regexp.escape(term)})"
        end.join

      Regexp.new("#{lookaheads}.*", flags)
    end

    def compile_term_regexps(pattern)
      terms = split_terms(pattern)
      flags = pattern.match?(/[A-Z]/) ? 0 : Regexp::IGNORECASE
      terms.map { |term| Regexp.new(Regexp.escape(term), flags) }
    end
  end
end
