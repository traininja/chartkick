require "json"
require "erb"

module Chartkick
  module Helper
    def line_chart(data_source, **options)
      chartkick_chart "LineChart", data_source, **options
    end

    def pie_chart(data_source, **options)
      chartkick_chart "PieChart", data_source, **options
    end

    def column_chart(data_source, **options)
      chartkick_chart "ColumnChart", data_source, **options
    end

    def bar_chart(data_source, **options)
      chartkick_chart "BarChart", data_source, **options
    end

    def area_chart(data_source, **options)
      chartkick_chart "AreaChart", data_source, **options
    end

    def scatter_chart(data_source, **options)
      chartkick_chart "ScatterChart", data_source, **options
    end

    def geo_chart(data_source, **options)
      chartkick_chart "GeoChart", data_source, **options
    end

    def timeline(data_source, **options)
      chartkick_chart "Timeline", data_source, **options
    end

    private

    def chartkick_chart(klass, data_source, **options)
      @chartkick_chart_id ||= 0
      options = chartkick_deep_merge(Chartkick.options, options)
      element_id = options.delete(:id) || "chart-#{@chartkick_chart_id += 1}"
      height = (options.delete(:height) || "300px").to_s
      width = (options.delete(:width) || "100%").to_s
      defer = !!options.delete(:defer)
      # content_for: nil must override default
      content_for = options.key?(:content_for) ? options.delete(:content_for) : Chartkick.content_for
      load_event = defined?(Turbolinks) ? "turbolinks:load" : "load"

      nonce = options.delete(:nonce)
      if nonce == true
        # Secure Headers also defines content_security_policy_nonce but it takes an argument
        # Rails 5.2 overrides this method, but earlier versions do not
        if respond_to?(:content_security_policy_nonce) && (content_security_policy_nonce rescue nil)
          # Rails 5.2
          nonce = content_security_policy_nonce
        elsif respond_to?(:content_security_policy_script_nonce)
          # Secure Headers
          nonce = content_security_policy_script_nonce
        end
      end
      nonce_html = nonce ? " nonce=\"#{ERB::Util.html_escape(nonce)}\"" : nil

      # html vars
      html_vars = {
        id: element_id
      }
      html_vars.each_key do |k|
        html_vars[k] = ERB::Util.html_escape(html_vars[k])
      end

      # css vars
      css_vars = {
        height: height,
        width: width
      }
      css_vars.each_key do |k|
        # limit to alphanumeric and % for simplicity
        # this prevents things like calc() but safety is the priority
        # dot does not need escaped in square brackets
        raise ArgumentError, "Invalid #{k}" unless css_vars[k] =~ /\A[a-zA-Z0-9%.]*\z/
        # we limit above, but escape for safety as fail-safe
        # to prevent XSS injection in worse-case scenario
        css_vars[k] = ERB::Util.html_escape(css_vars[k])
      end

      html = (options.delete(:html) || %(<div id="%{id}" style="height: %{height}; width: %{width}; text-align: center; color: #999; line-height: %{height}; font-size: 14px; font-family: 'Lucida Grande', 'Lucida Sans Unicode', Verdana, Arial, Helvetica, sans-serif;">Loading...</div>)) % html_vars.merge(css_vars)

      # js vars
      js_vars = {
        type: klass.to_json,
        id: element_id.to_json,
        data: data_source.respond_to?(:chart_json) ? data_source.chart_json : data_source.to_json,
        options: options.to_json
      }
      js_vars.each_key do |k|
        js_vars[k] = chartkick_json_escape(js_vars[k])
      end
      createjs = "new Chartkick[%{type}](%{id}, %{data}, %{options});" % js_vars

      if defer || defined?(Turbolinks)
        # TODO remove type in 4.0
        js = <<JS
<script type="text/javascript"#{nonce_html}>
  (function() {
    var createChart = function() { #{createjs} };
    if (window.addEventListener) {
      window.addEventListener("#{load_event}", createChart, true);
    } else if (window.attachEvent) {
      window.attachEvent("onload", createChart);
    } else {
      createChart();
    }
  })();
</script>
JS
      else
        # TODO remove type in 4.0
        js = <<JS
<script type="text/javascript"#{nonce_html}>
  #{createjs}
</script>
JS
      end

      if content_for
        content_for(content_for) { js.respond_to?(:html_safe) ? js.html_safe : js }
      else
        html += js
      end

      html.respond_to?(:html_safe) ? html.html_safe : html
    end

    # https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/hash/deep_merge.rb
    def chartkick_deep_merge(hash_a, hash_b)
      hash_a = hash_a.dup
      hash_b.each_pair do |k, v|
        tv = hash_a[k]
        hash_a[k] = tv.is_a?(Hash) && v.is_a?(Hash) ? chartkick_deep_merge(tv, v) : v
      end
      hash_a
    end

    # from https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/string/output_safety.rb
    JSON_ESCAPE = { "&" => '\u0026', ">" => '\u003e', "<" => '\u003c', "\u2028" => '\u2028', "\u2029" => '\u2029' }
    JSON_ESCAPE_REGEXP = /[\u2028\u2029&><]/u
    def chartkick_json_escape(s)
      if ERB::Util.respond_to?(:json_escape)
        ERB::Util.json_escape(s)
      else
        s.to_s.gsub(JSON_ESCAPE_REGEXP, JSON_ESCAPE)
      end
    end
  end
end
