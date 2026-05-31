namespace :admin do
  desc "Grant platform-admin role to a user by email: bin/rails 'admin:grant[me@example.com]'"
  task :grant, [:email] => :environment do |_t, args|
    email = args[:email].to_s.strip.downcase
    user = User.find_by(email:)
    abort "No user with email #{email.inspect}" unless user

    user.update!(role: :admin)
    puts "#{user.email} is now an admin."
  end

  desc "Revoke admin role (back to organizer): bin/rails 'admin:revoke[me@example.com]'"
  task :revoke, [:email] => :environment do |_t, args|
    email = args[:email].to_s.strip.downcase
    user = User.find_by(email:)
    abort "No user with email #{email.inspect}" unless user

    user.update!(role: :organizer)
    puts "#{user.email} is now an organizer."
  end
end
