# Idempotent seeds. Run with `bin/rails db:seed`.
#
# Ships the FIFA World Cup 2026 template — 48 teams (the 2026 tournament expanded
# to 48). Editable: organizers can adjust teams when they create a sweepstake.

WORLD_CUP_2026 = [
  # Hosts
  ["Canada", "🇨🇦"], ["Mexico", "🇲🇽"], ["United States", "🇺🇸"],
  # UEFA (16)
  ["England", "🏴󠁧󠁢󠁥󠁮󠁧󠁿"], ["France", "🇫🇷"], ["Spain", "🇪🇸"], ["Germany", "🇩🇪"],
  ["Portugal", "🇵🇹"], ["Netherlands", "🇳🇱"], ["Belgium", "🇧🇪"], ["Croatia", "🇭🇷"],
  ["Switzerland", "🇨🇭"], ["Austria", "🇦🇹"], ["Norway", "🇳🇴"], ["Scotland", "🏴󠁧󠁢󠁳󠁣󠁴󠁿"],
  ["Sweden", "🇸🇪"], ["Turkey", "🇹🇷"], ["Bosnia and Herzegovina", "🇧🇦"], ["Czechia", "🇨🇿"],
  # CONMEBOL (6)
  ["Argentina", "🇦🇷"], ["Brazil", "🇧🇷"], ["Uruguay", "🇺🇾"], ["Colombia", "🇨🇴"],
  ["Ecuador", "🇪🇨"], ["Paraguay", "🇵🇾"],
  # CONCACAF (3, non-host)
  ["Panama", "🇵🇦"], ["Curaçao", "🇨🇼"], ["Haiti", "🇭🇹"],
  # AFC (9, incl. Iraq via playoff)
  ["Japan", "🇯🇵"], ["South Korea", "🇰🇷"], ["Iran", "🇮🇷"], ["Australia", "🇦🇺"],
  ["Saudi Arabia", "🇸🇦"], ["Qatar", "🇶🇦"], ["Jordan", "🇯🇴"], ["Uzbekistan", "🇺🇿"],
  ["Iraq", "🇮🇶"],
  # CAF (10, incl. DR Congo via playoff)
  ["Morocco", "🇲🇦"], ["Senegal", "🇸🇳"], ["Ivory Coast", "🇨🇮"], ["Egypt", "🇪🇬"],
  ["Algeria", "🇩🇿"], ["Tunisia", "🇹🇳"], ["Ghana", "🇬🇭"], ["Cape Verde", "🇨🇻"],
  ["South Africa", "🇿🇦"], ["DR Congo", "🇨🇩"],
  # OFC (1)
  ["New Zealand", "🇳🇿"]
].freeze

template = CompetitionTemplate.find_or_initialize_by(slug: "world-cup-2026")
template.assign_attributes(
  name: "FIFA World Cup 2026",
  category: "football",
  year: 2026,
  status: :published
)
template.save!

# Rebuild entries so re-seeding stays in sync with the list above.
template.template_entries.delete_all
WORLD_CUP_2026.each_with_index do |(name, flag), i|
  template.template_entries.create!(name:, position: i + 1, metadata: { "flag" => flag })
end

puts "Seeded '#{template.name}' with #{template.template_entries.count} teams."
