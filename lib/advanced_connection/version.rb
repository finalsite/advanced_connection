
module AdvancedConnection
  MAJOR = 0
  MINOR = 0
  PATCH = 1

  VERSION     = "%d.%d.%d" % [ MAJOR, MINOR, PATCH ]
  GEM_VERSION = Gem::Version.new(VERSION)
end
