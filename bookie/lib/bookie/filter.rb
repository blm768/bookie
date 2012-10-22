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
          return jobs.where('server_id = ?', server.id)
        else
          return Bookie::Database::Job.limit(0)
        end
      end
      
      def by_server_type(jobs, server_type)
        return jobs.joins(:server).where('server_type = ?', Bookie::Database::SERVER_TYPE[server_type.intern])
      end
      
      def by_start_time(jobs, start_min, start_max)
        return jobs.where('? <= start_time AND start_time <= ?', start_min, start_max)
      end
      
      def by_end_time(jobs, end_min, end_max)
        return jobs.where('? <= end_time AND end_time <= ?', end_min, end_max)
      end
      
      class UnknownFilterError < ArgumentError
      end
      
      def apply_filters(jobs, filters)
        filters.each_pair do |name, value|
          case name
            when :user
              jobs = by_user(jobs, value)
            when :group
              jobs = by_group(jobs, value)
            when :server
              jobs = by_server(jobs, value)
            when :server_type
              jobs = by_server_type(jobs, value)
            when :start_time
              jobs = by_start_time(jobs, value[0], value[1])
            else
              raise UnknownFilterError.new("Unknown filter type '#{name}'")
          end
        end
        return jobs
      end
    end
  end
end