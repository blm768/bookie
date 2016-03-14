# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

unless WebUser.any?
  WebUser.create!(email: 'admin@bookie', password: 'change_this_password')
end
