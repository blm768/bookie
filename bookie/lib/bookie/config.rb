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
    
    def initialize(filename)
      file = File.open(filename)
      data = json.parse(file.read)
      file.close
      
      @server = data['Server'] || raise "No database server specified"
      @port = data['Port']
      @username = data['Username'] || "root"
      @password = data['Password'] || ""
    end
  end
end