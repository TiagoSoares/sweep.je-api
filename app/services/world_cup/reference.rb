module WorldCup
  # Static reference for the World Cup nations: FIFA three-letter code and flag
  # emoji per country. Used to (a) seed template entries with a stable
  # country_code + flag, and (b) attach flags to upstream football-data teams,
  # which only carry a name/tla (no emoji). Matching is by code or normalized name.
  module Reference
    # [name, FIFA code, flag]. Order mirrors the seed (favourites first), but order
    # is irrelevant for lookups.
    TEAMS = [
      ["France", "FRA", "🇫🇷"], ["Spain", "ESP", "🇪🇸"], ["England", "ENG", "🏴󠁧󠁢󠁥󠁮󠁧󠁿"], ["Brazil", "BRA", "🇧🇷"],
      ["Argentina", "ARG", "🇦🇷"], ["Portugal", "POR", "🇵🇹"], ["Germany", "GER", "🇩🇪"], ["Netherlands", "NED", "🇳🇱"],
      ["Belgium", "BEL", "🇧🇪"], ["Croatia", "CRO", "🇭🇷"], ["Uruguay", "URU", "🇺🇾"], ["Colombia", "COL", "🇨🇴"],
      ["Morocco", "MAR", "🇲🇦"], ["Switzerland", "SUI", "🇨🇭"], ["Japan", "JPN", "🇯🇵"], ["United States", "USA", "🇺🇸"],
      ["Mexico", "MEX", "🇲🇽"], ["Senegal", "SEN", "🇸🇳"], ["Ecuador", "ECU", "🇪🇨"], ["Austria", "AUT", "🇦🇹"],
      ["Sweden", "SWE", "🇸🇪"], ["Turkey", "TUR", "🇹🇷"], ["South Korea", "KOR", "🇰🇷"], ["Australia", "AUS", "🇦🇺"],
      ["Canada", "CAN", "🇨🇦"], ["Norway", "NOR", "🇳🇴"], ["Scotland", "SCO", "🏴󠁧󠁢󠁳󠁣󠁴󠁿"], ["Egypt", "EGY", "🇪🇬"],
      ["Ivory Coast", "CIV", "🇨🇮"], ["Czechia", "CZE", "🇨🇿"], ["Paraguay", "PAR", "🇵🇾"], ["Algeria", "ALG", "🇩🇿"],
      ["Tunisia", "TUN", "🇹🇳"], ["Iran", "IRN", "🇮🇷"], ["Ghana", "GHA", "🇬🇭"], ["Qatar", "QAT", "🇶🇦"],
      ["Saudi Arabia", "KSA", "🇸🇦"], ["Bosnia and Herzegovina", "BIH", "🇧🇦"], ["Iraq", "IRQ", "🇮🇶"], ["Jordan", "JOR", "🇯🇴"],
      ["Uzbekistan", "UZB", "🇺🇿"], ["Panama", "PAN", "🇵🇦"], ["South Africa", "RSA", "🇿🇦"], ["DR Congo", "COD", "🇨🇩"],
      ["Cape Verde", "CPV", "🇨🇻"], ["Curaçao", "CUW", "🇨🇼"], ["Haiti", "HAI", "🇭🇹"], ["New Zealand", "NZL", "🇳🇿"]
    ].freeze

    # Alternate upstream names that don't match our names exactly.
    NAME_ALIASES = {
      "usa" => "United States",
      "united states of america" => "United States",
      "korea republic" => "South Korea",
      "ir iran" => "Iran",
      "turkiye" => "Turkey",
      "cote divoire" => "Ivory Coast",
      "czech republic" => "Czechia",
      "bosnia herzegovina" => "Bosnia and Herzegovina",
      "dr congo" => "DR Congo",
      "congo dr" => "DR Congo",
      "cabo verde" => "Cape Verde"
    }.freeze

    FALLBACK_FLAG = "🏳️"

    module_function

    def normalize(value)
      I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]+/, " ").strip
    end

    def by_code
      @by_code ||= TEAMS.to_h { |name, code, flag| [code.downcase, { name:, code:, flag: }] }
    end

    def by_name
      @by_name ||= TEAMS.to_h { |name, code, flag| [normalize(name), { name:, code:, flag: }] }
    end

    # Look up a nation by FIFA code or (aliased, normalized) name. Returns the
    # { name:, code:, flag: } hash, or nil when unknown.
    def lookup(name: nil, code: nil)
      if code.present? && (hit = by_code[code.to_s.downcase])
        return hit
      end

      key = normalize(name)
      key = normalize(NAME_ALIASES[key]) if NAME_ALIASES.key?(key)
      by_name[key]
    end

    # Flag emoji for a nation (falls back to a neutral flag when unknown).
    def flag_for(name: nil, code: nil)
      lookup(name:, code:)&.fetch(:flag) || FALLBACK_FLAG
    end
  end
end
