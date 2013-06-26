
name "bookie_accounting"
maintainer "Ben Merritt"
homepage "http://github.com/blm768/bookie/"

replaces        "bookie_accounting"
install_path    "/opt/bookie"
build_version   Omnibus::BuildVersion.new.semver
build_iteration 1

# creates required build directories
dependency "preparation"

# bookie dependencies/components
dependency "bookie_accounting"
dependency "mysql2"

 version manifest file
dependency "version-manifest"

exclude "\.git*"
exclude "bundler\/git"
