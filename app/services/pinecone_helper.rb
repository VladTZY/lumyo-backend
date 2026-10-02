require "net/http"
require "json"
require "uri"

module PineconeHelper
  class Error < StandardError; end

  NAMESPACE = "notes"

  module_function

  def upsert_records(records)
    records.each_slice(50) do |batch|
      ndjson = batch.map { |r| r.to_json }.join("\n")
      request(:post, "/records/namespaces/#{NAMESPACE}/upsert", ndjson, content_type: "application/x-ndjson")
    end
  end

  def delete_by_filter(filter)
    request(:post, "/vectors/delete", { filter: filter, namespace: NAMESPACE }.to_json)
  end

  def delete_ids(ids)
    ids.each_slice(1000) do |batch|
      request(:post, "/vectors/delete", { ids: batch, namespace: NAMESPACE }.to_json)
    end
  end

  # Yields every vector id in the namespace that starts with prefix.
  def each_id(prefix: nil)
    return enum_for(:each_id, prefix: prefix) unless block_given?

    token = nil
    loop do
      query = { namespace: NAMESPACE, limit: 100, prefix: prefix, paginationToken: token }.compact
      page = request(:get, "/vectors/list?#{URI.encode_www_form(query)}") || {}
      Array(page["vectors"]).each { |v| yield v["id"] }
      token = page.dig("pagination", "next")
      break if token.blank?
    end
  end

  def search(text, top_k: 10, filter: nil)
    body = {
      query: {
        top_k: top_k,
        inputs: { text: text }
      },
      fields: %w[text note_id user_id title tags chunk_index]
    }
    body[:query][:filter] = filter if filter

    request(:post, "/records/namespaces/#{NAMESPACE}/search", body.to_json)
  end

  def request(method, path, body = nil, content_type: "application/json")
    api_key = ENV.fetch("PINECONE_API_KEY")
    host = ENV.fetch("PINECONE_INDEX_HOST")

    uri = URI("#{host}#{path}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    headers = {
      "Api-Key" => api_key,
      "Content-Type" => content_type,
      "Accept" => "application/json",
      "X-Pinecone-API-Version" => "2025-04"
    }

    req = case method
          when :get
            Net::HTTP::Get.new(uri, headers)
          when :post
            r = Net::HTTP::Post.new(uri, headers)
            r.body = body if body
            r
          end

    response = http.request(req)

    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Pinecone #{method.upcase} #{path} failed (#{response.code}): #{response.body}"
    end

    return nil if response.body.nil? || response.body.empty?

    JSON.parse(response.body)
  end

  private_class_method :request
end
