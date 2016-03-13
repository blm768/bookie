hostname 'localhost'
system_type 'dummy'
cores 4
memory 8000000
filter_jobs do |job|
  job.user_name != 'root'
end
