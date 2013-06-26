name "bookie_accounting"
version "1.1.1"

dependency "ruby"
dependency "rubygems"
dependency "bundler"

source :path => "../bookie"

relative_path "ruby-example"

build do
  bundle "install --without=development --path=#{install_dir}/embedded/service/gem"
  command "mkdir -p #{install_dir}/embedded/service/ruby-example"
  command "#{install_dir}/embedded/bin/rsync -a --delete --exclude=.git/*** --exclude=.gitignore ./ #{install_dir}/embedded/service/ruby-example/"
end
