# Idempotent seeds. Run with `bin/rails db:seed`.
#
# Ships the FIFA World Cup 2026 template — 48 teams (the 2026 tournament expanded
# to 48). Editable: organizers can adjust teams when they create a sweepstake.
#
# ORDER MATTERS: teams are listed best-odds first (favourites at the top, long
# shots at the bottom). The draw deals them in this order so favourites spread
# one-per-person. Odds are an approximate pre-tournament ranking.

WORLD_CUP_2026 = [
  ["France", "🇫🇷"], ["Spain", "🇪🇸"], ["Argentina", "🇦🇷"], ["England", "🏴󠁧󠁢󠁥󠁮󠁧󠁿"],
  ["Portugal", "🇵🇹"], ["Brazil", "🇧🇷"], ["Netherlands", "🇳🇱"], ["Morocco", "🇲🇦"],
  ["Belgium", "🇧🇪"], ["Germany", "🇩🇪"], ["Croatia", "🇭🇷"], ["Colombia", "🇨🇴"],
  ["Senegal", "🇸🇳"], ["Mexico", "🇲🇽"], ["United States", "🇺🇸"], ["Uruguay", "🇺🇾"],
  ["Japan", "🇯🇵"], ["Switzerland", "🇨🇭"], ["Iran", "🇮🇷"], ["Türkiye", "🇹🇷"],
  ["Ecuador", "🇪🇨"], ["Austria", "🇦🇹"], ["South Korea", "🇰🇷"], ["Australia", "🇦🇺"],
  ["Algeria", "🇩🇿"], ["Egypt", "🇪🇬"], ["Canada", "🇨🇦"], ["Norway", "🇳🇴"],
  ["Panama", "🇵🇦"], ["Côte d’Ivoire", "🇨🇮"], ["Sweden", "🇸🇪"], ["Paraguay", "🇵🇾"],
  ["Czechia", "🇨🇿"], ["Scotland", "🏴󠁧󠁢󠁳󠁣󠁴󠁿"], ["Tunisia", "🇹🇳"], ["DR Congo", "🇨🇩"],
  ["Uzbekistan", "🇺🇿"], ["Qatar", "🇶🇦"], ["Iraq", "🇮🇶"], ["South Africa", "🇿🇦"],
  ["Saudi Arabia", "🇸🇦"], ["Jordan", "🇯🇴"], ["Bosnia and Herzegovina", "🇧🇦"], ["Cape Verde", "🇨🇻"],
  ["Ghana", "🇬🇭"], ["Curaçao", "🇨🇼"], ["Haiti", "🇭🇹"], ["New Zealand", "🇳🇿"]
].freeze

template = CompetitionTemplate.find_or_initialize_by(slug: "world-cup-2026")
template.assign_attributes(
  name: "FIFA World Cup 2026",
  category: "football",
  year: 2026,
  status: :published,
  prediction_fields: ["Golden Ball", "Golden Boot", "Golden Glove"]
)
template.save!

# Rebuild entries so re-seeding stays in sync with the list above.
template.template_entries.delete_all
WORLD_CUP_2026.each_with_index do |(name, flag), i|
  template.template_entries.create!(name:, position: i + 1, metadata: { "flag" => flag })
end

puts "Seeded '#{template.name}' with #{template.template_entries.count} teams."
