# -*- coding: utf-8 -*-
# app/llm_client.rb

class LLMClient
  def initialize
    @base_url = "http://localhost:8000"
    @endpoint = "/chat"
  end

  def send_request(args, prompt)
    # Try to fix encoding issues - DragonRuby compatible approach
    begin
      if prompt.respond_to?(:force_encoding)
        prompt = prompt.force_encoding('UTF-8')
      end
    rescue => e
      puts "Encoding fix failed: #{e.message}"
    end

   prompt = "hi"
    
    puts "Sending request to #{@base_url}#{@endpoint}"
    puts "Prompt type: #{prompt.class}"
    puts "Prompt encoding: #{prompt.respond_to?(:encoding) ? prompt.encoding : 'unknown'}"
    puts "Prompt length: #{prompt.length}"
    raise ArgumentError, "prompt must be a String, got #{prompt.class}" unless prompt.is_a?(String)
    url = "#{@base_url}#{@endpoint}"
    
    # Build the JSON string manually (no json.rb needed)
    body_json = %({"model":"gpt-5-mini","input":#{prompt.to_s.inspect},"effort":"minimal"})
    
    headers = [
      "Content-Type: application/json",
      "Content-Length: #{body_json.length}"
    ]

    # Use http_post_body instead of http_post
    args.state.llm_result = args.gtk.http_post_body(url, body_json, headers)
    args.state.llm_printed = false
  end

  def handle_response(args)
    r = args.state.llm_result
    return nil unless r && r[:complete]

    code = r[:http_response_code]
    body = r[:response_data] || r[:response_body] || r[:body] || ""
    
    puts "Response code: #{code}"
    puts "Response body: #{body.inspect}"
    puts "Response body type: #{body.class}"

    # Clear the handle so it doesn't repeat
    args.state.llm_result = nil

    return nil unless code && code >= 200 && code < 300

    # Your FastAPI returns {"response":"..."}
    if body.is_a?(String)
      # naive extraction without json.rb
      if (m = body.match(/"response"\s*:\s*"([^"]*)"/))
        m[1]
      else
        body
      end
    else
      body.to_s
    end
  end
end
