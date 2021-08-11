# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2021  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module Redmine
  module WikiFormatting
    module CommonMark
      # sanitizes rendered HTML using the Sanitize gem
      class SanitizationFilter < HTML::Pipeline::SanitizationFilter
        def whitelist
          @@whitelist ||= customize_whitelist(super.deep_dup)
        end

        private

        # customizes the whitelist defined in
        # https://github.com/jch/html-pipeline/blob/master/lib/html/pipeline/sanitization_filter.rb
        def customize_whitelist(whitelist)
          # Disallow `name` attribute globally, allow on `a`
          whitelist[:attributes][:all].delete("name")
          whitelist[:attributes]["a"].push("name")

          # allow class on code tags (this holds the language info from fenced
          # code bocks and has the format language-foo)
          whitelist[:attributes]["code"] = %w(class)
          whitelist[:transformers].push lambda{|env|
            node = env[:node]
            return unless node.name == "code"
            return unless node.has_attribute?("class")

            unless /\Alanguage-(\w+)\z/.match?(node["class"])
              node.remove_attribute("class")
            end
          }

          # Allow table cell alignment by style attribute
          #
          # Only necessary if we used the TABLE_PREFER_STYLE_ATTRIBUTES
          # commonmarker option (which we do not, currently).
          # By default, the align attribute is used (which is allowed on all
          # elements).
          # whitelist[:attributes]["th"] = %w(style)
          # whitelist[:attributes]["td"] = %w(style)
          # whitelist[:css] = { properties: ["text-align"] }

          # Allow `id` in a and li elements for footnotes
          # and remove any `id` properties not matching for footnotes
          whitelist[:attributes]["a"].push "id"
          whitelist[:attributes]["li"] = %w(id)
          whitelist[:transformers].push lambda{|env|
            node = env[:node]
            return unless node.name == "a" || node.name == "li"
            return unless node.has_attribute?("id")
            return if node.name == "a" && node["id"] =~ /\Afnref\d+\z/
            return if node.name == "li" && node["id"] =~ /\Afn\d+\z/

            node.remove_attribute("id")
          }

          # allow the same set of URL schemes for links as is the default in
          # Redmine::Helpers::URL#uri_with_safe_scheme?
          whitelist[:protocols]["a"]["href"] = [
            'http', 'https', 'ftp', 'mailto', :relative
          ]

          whitelist
        end
      end
    end
  end
end
