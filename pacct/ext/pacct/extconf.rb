require 'mkmf'

=begin
if ENV['COVERAGE']
  $CFLAGS << ' -fprofile-arcs -ftest-coverage'
end
=end

create_makefile("pacct/pacct_c");
