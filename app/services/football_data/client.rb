require "net/http"
require "json"

module FootballData
  # Raised for any football-data.org problem the caller should treat as
  # "tournament data unavailable".
  class Error < StandardError; end

  # No API token configured (FOOTBALL_DATA_API_TOKEN unset).
  class NotConfigured < Error; end

  # Upstream failed (network error, 429 after retries, 5xx) and no cached copy
  # was available to fall back to.
  class Unavailable < Error; end

  # Thin client for the football-data.org v4 API. Caches responses server-side to
  # respect the free tier's ~10 req/min limit: a short "fresh" window plus a much
  # longer "last good" copy that is served when upstream is failing.
  class Client
    BASE_URL = "https://api.football-data.org/v4".freeze
    FRESH_TTL = 60.seconds
    LAST_GOOD_TTL = 1.day
    MAX_RETRIES = 2          # extra attempts on HTTP 429
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 8

    def initialize(token: ENV["FOOTBALL_DATA_API_TOKEN"], cache: Rails.cache, logger: Rails.logger)
      @token = token.presence
      @cache = cache
      @logger = logger
    end

    def configured?
      @token.present?
    end

    # Group standings for a competition (e.g. "WC").
    def standings(competition_code)
      cached_get("/competitions/#{competition_code}/standings")
    end

    # All matches for a competition (group + knockout, with scores/status).
    def matches(competition_code)
      cached_get("/competitions/#{competition_code}/matches")
    end

    private

    def cached_get(path)
      raise NotConfigured, "FOOTBALL_DATA_API_TOKEN is not set" unless configured?

      fresh = @cache.read(fresh_key(path))
      return fresh if fresh

      begin
        data = fetch(path)
        @cache.write(fresh_key(path), data, expires_in: FRESH_TTL)
        @cache.write(last_good_key(path), data, expires_in: LAST_GOOD_TTL)
        data
      rescue Unavailable => e
        last_good = @cache.read(last_good_key(path))
        if last_good
          @logger.warn("[FootballData] serving last-good cache for #{path}: #{e.message}")
          return last_good
        end
        raise
      end
    end

    # One HTTP GET with a small retry/backoff on 429. Returns parsed JSON or
    # raises Unavailable.
    def fetch(path, attempt: 0)
      uri = URI("#{BASE_URL}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Get.new(uri)
      request["X-Auth-Token"] = @token
      request["Accept"] = "application/json"

      response = http.request(request)

      case response.code.to_i
      when 200
        JSON.parse(response.body)
      when 429
        if attempt < MAX_RETRIES
          sleep(backoff(attempt)) unless Rails.env.test?
          fetch(path, attempt: attempt + 1)
        else
          raise Unavailable, "rate limited (429) after #{MAX_RETRIES + 1} attempts"
        end
      else
        raise Unavailable, "football-data.org returned #{response.code} for #{path}"
      end
    rescue JSON::ParserError => e
      raise Unavailable, "invalid JSON from #{path}: #{e.message}"
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError => e
      raise Unavailable, "network error for #{path}: #{e.class}: #{e.message}"
    end

    # 0 -> ~1s, 1 -> ~2s (free tier resets per minute, but a short backoff is
    # enough to clear a transient burst).
    def backoff(attempt)
      2**attempt
    end

    def fresh_key(path)
      "football_data:fresh:#{path}"
    end

    def last_good_key(path)
      "football_data:last_good:#{path}"
    end
  end
end
