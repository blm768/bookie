require 'bookie/database'

#Connect to the Bookie database.
Bookie::Database::Model.establish_connection "bookie_#{Rails.env}"

