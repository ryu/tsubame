email = ENV.fetch("TSUBAME_EMAIL", "admin@example.com")
User.find_or_create_by!(email_address: email)
