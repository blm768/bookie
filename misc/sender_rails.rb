hostname 'localhost'
system_type 'standalone'
cores 4
memory 8000000
filter_jobs do |job|
  job.user_name != 'root'
end
