require 'bookie/config'
require 'bookie/extensions'

require 'active_record'

require 'bookie/database/job'
require 'bookie/database/job_summary'
require 'bookie/database/system'
require 'bookie/database/system_type'
require 'bookie/database/user'

module Bookie
  ##
  #Contains database-related code and models
  module Database
    ##
    #Location of database migrations
    MIGRATIONS_PATH = File.expand_path('./database/migrations/', File.dirname(__FILE__))
    class << self;
      ##
      #Finds the latest database version (the highest migration version)
      def latest_version
        max_version = 0
        Dir.entries(MIGRATIONS_PATH).each do |migration|
          match = /^([0-9]+).*\.rb$/.match(migration)
          if match then
            version = match[1].to_i
            max_version = version if version > max_version
          end
        end
        max_version
      end

      ##
      #Migrates to the target version
      def migrate(target = nil)
        target ||= latest_version
        ActiveRecord::Migrator.migrate(MIGRATIONS_PATH, target)
      end
    end
  end
end
