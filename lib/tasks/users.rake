namespace :users do
  desc "Reset a user's password and print the new one: bin/rails users:reset_password[admin@example.com]"
  task :reset_password, [ :email_address ] => :environment do |_task, args|
    user = User.find_by!(email_address: args.fetch(:email_address))
    password = SecureRandom.base58(20)
    user.update!(password:, password_confirmation: password)
    user.sessions.destroy_all
    puts "New password for #{user.email_address}: #{password}"
  end
end
