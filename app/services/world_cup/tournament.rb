module WorldCup
  # Builds the public "tournament" payload for a World Cup sweepstake from
  # football-data.org standings + matches, deriving each team's alive/eliminated
  # status and mapping it back onto the sweepstake's entries.
  #
  # Pure transformation given the upstream JSON; the HTTP/caching lives in
  # FootballData::Client (injected, so it's easy to stub in specs).
  class Tournament
    # How many teams advance from each group when the knockout draw isn't known
    # yet (used only mid-group-stage; once knockout matches exist they're
    # authoritative). The 2026 best-third-place rule is approximated by top 2.
    GROUP_ADVANCE = 2

    KNOCKOUT_ORDER = %w[LAST_32 LAST_16 QUARTER_FINALS SEMI_FINALS THIRD_PLACE FINAL].freeze

    def initialize(sweepstake, client: FootballData::Client.new)
      @sweepstake = sweepstake
      @client = client
      @code = sweepstake.football_competition_code
    end

    def call
      standings = @client.standings(@code)
      matches = @client.matches(@code)

      @group_tables = group_tables(standings)
      @all_matches = Array(matches["matches"])
      @teams = build_team_registry
      derive_statuses

      {
        competition: competition(standings),
        last_updated: Time.current.utc.iso8601,
        current_stage: current_stage,
        groups: groups_payload,
        knockout: knockout_payload,
        teams: teams_payload,
        entries: entries_payload
      }
    end

    private

    # --- upstream parsing ---------------------------------------------------

    def group_tables(standings)
      Array(standings["standings"])
        .select { |s| s["group"].present? && s["type"] == "TOTAL" }
        .map do |s|
          key = group_key(s["group"])
          { key:, name: humanize_group(key), rows: Array(s["table"]) }
        end
    end

    # Canonical group key. football-data returns "Group A" in /standings but
    # "GROUP_A" in /matches, so normalize both to "GROUP_A" before comparing.
    def group_key(raw)
      raw.to_s.strip.upcase.gsub(/\s+/, "_")
    end

    def competition(standings)
      comp = standings["competition"] || {}
      season = standings["season"] || {}
      label = season["startDate"].to_s[0, 4].presence || @sweepstake.competition_template&.year&.to_s
      { code: @code, name: comp["name"].presence || "FIFA World Cup", season: label }
    end

    def knockout_matches
      @all_matches.reject { |m| m["stage"] == "GROUP_STAGE" }
    end

    # team_id -> { id, name, flag, code }. Gathered from standings tables and
    # match line-ups (skipping not-yet-decided knockout slots with no team id).
    def build_team_registry
      registry = {}
      @group_tables.each do |table|
        table[:rows].each { |row| add_team(registry, row["team"]) }
      end
      @all_matches.each do |m|
        add_team(registry, m["homeTeam"])
        add_team(registry, m["awayTeam"])
      end
      registry
    end

    def add_team(registry, raw)
      id = raw && raw["id"]
      return if id.blank?
      return if registry.key?(id)

      code = raw["tla"].presence
      registry[id] = { id:, name: raw["name"], code:, flag: WorldCup::Reference.flag_for(name: raw["name"], code:) }
    end

    # --- status derivation --------------------------------------------------

    def derive_statuses
      @team_group = {}
      @team_position = {}
      @group_tables.each do |table|
        table[:rows].each do |row|
          tid = row.dig("team", "id")
          next if tid.blank?

          @team_group[tid] = table[:key]
          @team_position[tid] = row["position"]
        end
      end

      @qualified = Set.new
      @lost_ko = Set.new
      knockout_matches.each do |m|
        home = m.dig("homeTeam", "id")
        away = m.dig("awayTeam", "id")
        @qualified << home if home.present?
        @qualified << away if away.present?
        next unless m["status"] == "FINISHED"

        winner = m.dig("score", "winner")
        @lost_ko << away if winner == "HOME_TEAM" && away.present?
        @lost_ko << home if winner == "AWAY_TEAM" && home.present?
      end

      @group_complete = {}
      @group_tables.each do |table|
        ms = @all_matches.select { |m| m["stage"] == "GROUP_STAGE" && group_key(m["group"]) == table[:key] }
        @group_complete[table[:key]] = ms.any? && ms.all? { |m| m["status"] == "FINISHED" }
      end
    end

    def team_status(team_id)
      return "eliminated" if @lost_ko.include?(team_id)
      return "alive" if @qualified.include?(team_id) # reached (and not lost) the knockout

      group = @team_group[team_id]
      return "alive" unless group && @group_complete[group]

      # Group is decided and they're not in the knockout: top finishers are
      # advancing (kept alive even if the bracket hasn't populated their slot yet).
      position = @team_position[team_id]
      position && position <= GROUP_ADVANCE ? "alive" : "eliminated"
    end

    def standing_status(team_id)
      return "eliminated" if team_status(team_id) == "eliminated"

      group = @team_group[team_id]
      advanced = @qualified.include?(team_id) ||
                 (group && @group_complete[group] && @team_position[team_id].to_i.between?(1, GROUP_ADVANCE))
      advanced ? "advanced" : "active"
    end

    # --- payload builders ---------------------------------------------------

    def groups_payload
      @group_tables.map do |table|
        {
          name: table[:name],
          standings: table[:rows].map { |row| standing_row(row) }
        }
      end
    end

    def standing_row(row)
      tid = row.dig("team", "id")
      {
        team: team_ref(tid),
        position: row["position"],
        played: row["playedGames"],
        won: row["won"],
        draw: row["draw"],
        lost: row["lost"],
        points: row["points"],
        goals_for: row["goalsFor"],
        goals_against: row["goalsAgainst"],
        goal_difference: row["goalDifference"],
        status: standing_status(tid)
      }
    end

    def knockout_payload
      by_stage = knockout_matches.group_by { |m| m["stage"] }
      by_stage
        .sort_by { |stage, _| KNOCKOUT_ORDER.index(stage) || 99 }
        .map do |stage, ms|
          {
            stage:,
            matches: ms.sort_by { |m| m["utcDate"].to_s }.map { |m| knockout_match(m) }
          }
        end
    end

    def knockout_match(m)
      {
        id: m["id"],
        home: match_team(m["homeTeam"]),
        away: match_team(m["awayTeam"]),
        home_score: m.dig("score", "fullTime", "home"),
        away_score: m.dig("score", "fullTime", "away"),
        winner: map_winner(m.dig("score", "winner")),
        status: map_status(m["status"]),
        utc_date: m["utcDate"]
      }
    end

    def teams_payload
      @teams.values.map { |t| t.slice(:id, :name, :flag, :code).merge(status: team_status(t[:id])) }
    end

    def entries_payload
      indexes = entry_match_indexes
      @sweepstake.entries.filter_map do |entry|
        team_id = match_entry_to_team(entry, indexes)
        if team_id.nil?
          Rails.logger.warn("[WorldCup::Tournament] no football-data team for entry #{entry.public_id} (#{entry.name})")
          next
        end
        { entry_id: entry.public_id, team_id:, status: team_status(team_id) }
      end
    end

    # --- entry -> team matching --------------------------------------------

    def entry_match_indexes
      by_code = {}
      by_name = {}
      @teams.each_value do |t|
        by_code[t[:code].to_s.downcase] = t[:id] if t[:code].present?
        by_name[WorldCup::Reference.normalize(t[:name])] = t[:id]
      end
      { by_code:, by_name: }
    end

    def match_entry_to_team(entry, indexes)
      meta = entry.metadata.is_a?(Hash) ? entry.metadata : {}

      fd_id = meta["fd_team_id"]
      return fd_id.to_i if fd_id.present? && @teams.key?(fd_id.to_i)

      # Country code from metadata, else derived from the entry name via the
      # reference — so entries named slightly differently to football-data (e.g.
      # "DR Congo" vs "Congo DR") still match by their shared FIFA code.
      code = (meta["country_code"].presence || WorldCup::Reference.lookup(name: entry.name)&.fetch(:code)).to_s.downcase
      return indexes[:by_code][code] if code.present? && indexes[:by_code].key?(code)

      indexes[:by_name][WorldCup::Reference.normalize(entry.name)]
    end

    # --- small helpers ------------------------------------------------------

    def team_ref(team_id)
      @teams[team_id] || { id: team_id, name: nil, flag: WorldCup::Reference::FALLBACK_FLAG, code: nil }
    end

    # A team object straight from a match line-up (handles not-yet-decided slots).
    def match_team(raw)
      id = raw && raw["id"]
      return team_ref(id) if id.present?

      { id: nil, name: raw && raw["name"], flag: nil, code: nil }
    end

    def current_stage
      return "GROUP_STAGE" if @all_matches.empty?

      pending = @all_matches.reject { |m| m["status"] == "FINISHED" }
      return "FINISHED" if pending.empty?

      pending.min_by { |m| m["utcDate"].to_s }["stage"]
    end

    def map_status(status)
      case status
      when "IN_PLAY", "PAUSED" then "IN_PLAY"
      when "FINISHED" then "FINISHED"
      else "SCHEDULED"
      end
    end

    def map_winner(winner)
      case winner
      when "HOME_TEAM" then "HOME"
      when "AWAY_TEAM" then "AWAY"
      end
    end

    def humanize_group(key)
      key.to_s.split("_").map(&:capitalize).join(" ")
    end
  end
end
