hostname 'localhost'
system_type 'dummy'
filter_jobs do |job|
  job.user_name != 'root'
end
