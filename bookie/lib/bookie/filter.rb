require 'bookie/database'

module Bookie
  module Filter
    class << self;
      def by_user(jobs, user_name)
        #To do: optimize?
        return jobs.joins(:user).where('users.name = ?', user_name)
      end
      
      def by_group(jobs, group_name)
        group = Bookie::Database::Group.where('name = ?', group_name).first
        if group
          return jobs.joins(:user).where('group_id = ?', group.id)
        else
          return Bookie::Database::Job.limit(0)
        end
      end
      
      def by_server(jobs, server_name)
        server = Bookie::Database::Server.where('name = ?', server_name).first
        if server
          jobs = jobs.where('server_id = ?', server.id)
        else
          jobs = Bookie::Database::Job.limit(0)
        end
      end
      
      def by_start_time(jobs, start_min, start_max)
        return jobs.where('? <= start_time AND start_time <= ?', start_min, start_max)
      end
    end
  end
end