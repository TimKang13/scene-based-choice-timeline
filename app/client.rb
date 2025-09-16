# -*- coding: utf-8 -*-
# app/llm_client.rb

class LLMClient
  def initialize
    @base_url = "http://localhost:8000"
  end

  # Minimal JSON string escaper compatible with DragonRuby (no encode/gsub)
  def json_escape(str)
    s = str.to_s
    out = ""
    i = 0
    while i < s.length
      ch = s[i]
      # Fallback per-char access; handle common control chars and quotes
      if ch == '"'
        out << '\\"'
      elsif ch == '\\'
        out << '\\\\'
      elsif ch == "\n"
        out << '\\n'
      elsif ch == "\r"
        out << '\\r'
      elsif ch == "\t"
        out << '\\t'
      else
        # Control chars < 0x20: escape as \u00XX when possible
        code = ch.ord rescue nil
        if code && code < 32
          hex = code.to_s(16)
          out << "\\u" << ("0" * (4 - hex.length)) << hex
        else
          out << ch
        end
      end
      i += 1
    end
    out
  end

  def send_request(args, endpoint, prompt)
    # Try to fix encoding issues - DragonRuby compatible approach
    
    puts "Sending request to #{@base_url}#{endpoint}"
    puts "Prompt type: #{prompt.class}"
    puts "Prompt encoding: #{prompt.respond_to?(:encoding) ? prompt.encoding : 'unknown'}"
    puts "Prompt length: #{prompt.length}"
    raise ArgumentError, "prompt must be a String, got #{prompt.class}" unless prompt.is_a?(String)
    url = "#{@base_url}#{endpoint}"
    
    # Build the JSON string manually (no json.rb needed)
    escaped_input = json_escape(prompt)
    body_json = %({"model":"gpt-5-mini","input":"#{escaped_input}","effort":"minimal"})
    
    headers = [
      "Content-Type: application/json",
      "Content-Length: #{body_json.bytesize}"
    ]

    # Use http_post_body instead of http_post
    args.state.llm_result = args.gtk.http_post_body(url, body_json, headers)
    args.state.llm_printed = false
  end

  def handle_response(args)
    r = args.state.llm_result
    puts "DEBUG: llm_result: #{r.inspect}"
    puts "DEBUG: llm_result complete?: #{r && r[:complete]}"
    
    return nil unless r && r[:complete]

    code = r[:http_response_code]
    body = r[:response_data] || r[:response_body] || r[:body] || ""
    
    puts "Response code: #{code}"
    # Avoid .inspect here because it escapes UTF-8 into \x.. sequences
    puts "Response body: #{body}"
    puts "Response body type: #{body.class}"

    # Clear the handle so it doesn't repeat
    args.state.llm_result = nil

    return nil unless code && code >= 200 && code < 300

    # Prefer proper JSON parsing to preserve UTF-8
    if body.is_a?(String)
      parsed = nil
      begin
        parsed = args.gtk.parse_json(body)
      rescue
        parsed = nil
      end

      if parsed && parsed.is_a?(Hash) && (parsed.key?('response') || parsed.key?(:response))
        inner = parsed['response'] || parsed[:response]
        return inner.is_a?(String) ? inner : inner.to_s
      end

      # Fallback to manual extraction if JSON parsing failed
      if body.include?("\"response\"")
        start_idx = body.index("\"response\"")
        if start_idx
          colon_idx = body.index(':', start_idx)
          if colon_idx
            quote_start = body.index('"', colon_idx)
            if quote_start
              quote_end = quote_start + 1
              while quote_end < body.length
                if body[quote_end] == '\\' && quote_end + 1 < body.length
                  quote_end += 2
                elsif body[quote_end] == '"'
                  break
                else
                  quote_end += 1
                end
              end
              return body[quote_start + 1...quote_end] if quote_end < body.length
            end
          end
        end
      end
      return body
    else
      return body.to_s
    end
  end
end
