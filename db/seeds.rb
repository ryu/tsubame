# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create default user for single-user feed reader
email = ENV.fetch("TSUBAME_EMAIL") { abort "TSUBAME_EMAIL environment variable is required" }
password = ENV.fetch("TSUBAME_PASSWORD") { abort "TSUBAME_PASSWORD environment variable is required" }

User.find_or_create_by!(email_address: email) do |user|
  user.password = password
end
