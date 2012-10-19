require 'bookie/database'

module Bookie
  module Filter
    def by_user(jobs, user_name)
      #To do: handle group changes.
      user = Bookie::Database::User.where('name = ?', user_name).first
      if user
        return jobs.where('user_id = ?', user.id)
      else
        #To do: optimize? (especially for long queries)
        return jobs.limit(0)
      end
    end
    
    def by_group(jobs, group_name)
      group = Bookie::Database::Group.where('name = ?', group_name).first
      if group
        return jobs.joins(:user).where('user_id = users.id && group_id = ?', group.id)
      else
        return jobs.limit(0)
      end
    end
    
    def by_start(jobs, start_min, start_max)
      
    end
  end
end