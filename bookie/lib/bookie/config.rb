module Bookie
  class Config
    #The database server's hostname
    attr_accessor :server
    #The database server's port
    #
    #If nil, use the default port.
    attr_accessor :port
    #The username for the database
    #
    #Defaults to "root"
    attr_accessor :username
    #The password for the database
    #
    #Defaults to ""
    attr_accessor :password
    #A set containing the names of users to be excluded
    #
    #Defaults to an empty set
    attr_accessor :excluded_users
    
    def initialize(filename)
      file = File.open(filename)
      data = json.parse(file.read)
      file.close
      
      @server = data['Server'] || raise "No database server specified"
      @port = data['Port']
      @username = data['Username'] || "root"
      @password = data['Password'] || ""
      
      excluded_users_array = config['Excluded users'] || []
      raise TypeError("Invalid data type for JSON field 'Excluded users'") unless excluded_users_array.class == Array
      
      @excluded_users = Set.new(excluded_users_array)
    end
  end
end