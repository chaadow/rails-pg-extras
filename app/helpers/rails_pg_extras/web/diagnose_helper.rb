# frozen_string_literal: true

module RailsPgExtras
  module Web
    module DiagnoseHelper
      COLLAPSE_AFTER = 5
      HOT_CHECKS = %i[new_page_updates low_hot_same_page].freeze

      def humanize_check_name(check_name)
        check_name.to_s.tr("_", " ")
      end

      def diagnose_card_classes(ok)
        ok ? "border-green-200 bg-green-50" : "border-red-200 bg-red-50"
      end

      def diagnose_toggle_classes(ok, expanded:)
        [
          "w-full flex flex-wrap items-center gap-3 px-4 py-3 text-left",
          (expanded ? "border-b" : nil),
          (ok ? "border-green-200 hover:bg-green-100" : "border-red-200 hover:bg-red-100"),
        ].compact.join(" ")
      end

      def diagnose_badge_classes(ok)
        ok ? "bg-green-600 text-white" : "bg-red-600 text-white"
      end

      def diagnose_count_badge_classes(ok)
        ok ? "bg-green-200 text-green-900" : "bg-red-200 text-red-900"
      end

      def diagnose_body_classes(ok, expanded:)
        [
          "px-4 py-3",
          (ok ? "text-green-900" : "text-red-900"),
          ("hidden" unless expanded),
        ].compact.join(" ")
      end

      def diagnose_finding_count(message, check_name: nil)
        return nil if message.blank?

        text = message.to_s.strip
        check = check_name&.to_sym

        if HOT_CHECKS.include?(check) || hot_style_message?(text)
          count = hot_table_blocks(text).size
          return nil if count.zero?

          { count: count, label: count == 1 ? "table" : "tables" }
        elsif list_style_message?(text)
          _header, remainder = split_list_header(text)
          count = split_list_items(remainder).size
          return nil if count.zero?

          { count: count, label: count == 1 ? "item" : "items" }
        end
      end

      def format_diagnose_message(message, check_name: nil)
        return "".html_safe if message.blank?

        text = message.to_s.strip
        check = check_name&.to_sym

        if HOT_CHECKS.include?(check) || hot_style_message?(text)
          format_hot_diagnose_message(text)
        elsif list_style_message?(text)
          format_list_diagnose_message(text)
        else
          content_tag(:div, simple_format(h(text), {}, sanitize: false), class: "whitespace-pre-wrap leading-relaxed")
        end
      end

      private

      def hot_style_message?(text)
        text.match?(/'[^\n']+':\n/)
      end

      def list_style_message?(text)
        # Multi-item lists use ",\n"; single-item FK-style messages use "detected: item."
        text.include?(",\n") || text.match?(/detected:\n/) || text.match?(/detected: \S/)
      end

      def format_list_diagnose_message(text)
        _header, remainder = split_list_header(text)
        items = split_list_items(remainder)

        if items.empty?
          return content_tag(:div, simple_format(h(text), {}, sanitize: false), class: "whitespace-pre-wrap leading-relaxed")
        end

        parts = []
        parts << content_tag(:ul, class: "list-disc pl-5 space-y-1") do
          safe_join(
            items.each_with_index.map do |item, index|
              options = { class: "leading-snug" }
              if index >= COLLAPSE_AFTER
                options[:class] = "#{options[:class]} hidden"
                options[:data] = { pg_extras_collapse: true }
              end
              content_tag(:li, item, options)
            end,
          )
        end

        if items.size > COLLAPSE_AFTER
          parts << content_tag(
            :button,
            "Show all #{items.size} items",
            type: "button",
            class: "mt-2 text-sm font-semibold text-blue-700 hover:text-blue-900 underline",
            data: {
              pg_extras_collapse_toggle: true,
              expanded_label: "Show fewer items",
              collapsed_label: "Show all #{items.size} items",
            },
          )
        end

        safe_join(parts)
      end

      def split_list_header(text)
        if text.include?(":\n")
          header, remainder = text.split(":\n", 2)
          ["#{header}:", remainder.to_s]
        elsif text.include?(": ")
          header, remainder = text.split(": ", 2)
          ["#{header}:", remainder.to_s]
        else
          [nil, text]
        end
      end

      def split_list_items(remainder)
        remainder.to_s
          .sub(/\.\z/, "")
          .split(",\n")
          .flat_map { |chunk| chunk.split(/\n(?!')/) }
          .map { |item| item.strip.sub(/,\z/, "").sub(/\.\z/, "") }
          .reject(&:blank?)
      end

      def hot_table_blocks(text)
        paragraphs = text.split(/\n{2,}/).map(&:strip).reject(&:blank?)
        paragraphs.drop(1).select { |paragraph| paragraph.match?(/\A'[^\n']+':/) }
      end

      def format_hot_diagnose_message(text)
        paragraphs = text.split(/\n{2,}/).map(&:strip).reject(&:blank?)
        return content_tag(:div, simple_format(h(text), {}, sanitize: false), class: "whitespace-pre-wrap leading-relaxed") if paragraphs.empty?

        # Card title already names the check; skip the echoed summary line.
        paragraphs.shift
        table_blocks = []
        prose = []

        paragraphs.each do |paragraph|
          if paragraph.match?(/\A'[^\n']+':/)
            table_blocks << paragraph
          else
            prose << paragraph
          end
        end

        parts = []

        if table_blocks.any?
          parts << content_tag(:div, class: "space-y-3") do
            safe_join(
              table_blocks.each_with_index.map do |block, index|
                render_hot_table_block(block, hidden: index >= COLLAPSE_AFTER)
              end,
            )
          end

          if table_blocks.size > COLLAPSE_AFTER
            parts << content_tag(
              :button,
              "Show all #{table_blocks.size} tables",
              type: "button",
              class: "mt-3 text-sm font-semibold text-blue-700 hover:text-blue-900 underline",
              data: {
                pg_extras_collapse_toggle: true,
                expanded_label: "Show fewer tables",
                collapsed_label: "Show all #{table_blocks.size} tables",
              },
            )
          end
        end

        if prose.any?
          parts << render_hot_info_callout(prose)
        end

        safe_join(parts)
      end

      def render_hot_info_callout(prose)
        icon = <<~SVG.html_safe
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-5 h-5 flex-shrink-0 mt-0.5" aria-hidden="true">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
          </svg>
        SVG

        content_tag(
          :aside,
          class: "mt-4 flex gap-3 rounded-lg border border-blue-200 bg-blue-50 px-4 py-3 text-sm text-blue-900",
          role: "note",
        ) do
          body = content_tag(:div, class: "min-w-0 space-y-2 leading-relaxed") do
            safe_join([
              content_tag(:p, "Why this matters", class: "font-semibold text-blue-900"),
              *prose.map { |p| content_tag(:p, p, class: "text-blue-900") },
            ])
          end

          safe_join([icon, body])
        end
      end

      def render_hot_table_block(block, hidden: false)
        lines = block.split("\n").map(&:strip).reject(&:blank?)
        title_line = lines.shift.to_s
        table_name = title_line[/'\K[^']+/] || title_line.sub(/:\z/, "")

        classes = "rounded-lg border border-gray-300 bg-white px-3 py-2"
        classes = "#{classes} hidden" if hidden
        options = { class: classes }
        options[:data] = { pg_extras_collapse: true } if hidden

        content_tag(:div, options) do
          title = content_tag(:div, table_name, class: "font-semibold text-gray-900 mb-1")
          metrics = content_tag(:dl, class: "grid grid-cols-1 gap-1 text-sm") do
            safe_join(
              lines.map do |line|
                key, value = line.split(":", 2)
                next if key.blank? || value.blank?

                content_tag(:div, class: "flex flex-wrap gap-x-2") do
                  safe_join([
                    content_tag(:dt, "#{key.strip}:", class: "font-medium text-gray-700"),
                    content_tag(:dd, value.strip, class: "text-gray-800"),
                  ])
                end
              end.compact,
            )
          end

          safe_join([title, metrics])
        end
      end
    end
  end
end
