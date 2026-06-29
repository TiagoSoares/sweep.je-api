# Idempotent seeds. Run with `bin/rails db:seed`.
#
# Ships the FIFA World Cup 2026 template — 48 teams (the 2026 tournament expanded
# to 48). Editable: organizers can adjust teams when they create a sweepstake.
#
# ORDER MATTERS: teams are listed best-odds first (favourites at the top, long
# shots at the bottom). The draw deals them in this order so favourites spread
# one-per-person. Odds are an approximate pre-tournament ranking. The team list
# (name + FIFA code + flag) lives in WorldCup::Reference so it's shared with the
# live-tournament feature.

template = CompetitionTemplate.find_or_initialize_by(slug: "world-cup-2026")
template.assign_attributes(
  name: "FIFA World Cup 2026",
  category: "football",
  year: 2026,
  status: :published,
  prediction_fields: ["Golden Ball", "Golden Boot", "Golden Glove"]
)
template.save!

# Rebuild entries so re-seeding stays in sync with the reference list. Each entry
# carries its flag + country_code so live data can be matched back to football-data.
template.template_entries.delete_all
WorldCup::Reference::TEAMS.each_with_index do |(name, code, flag), i|
  template.template_entries.create!(
    name:, position: i + 1,
    metadata: { "flag" => flag, "country_code" => code }
  )
end

puts "Seeded '#{template.name}' with #{template.template_entries.count} teams."
