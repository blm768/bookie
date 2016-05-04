require 'bookie/database'

module Bookie::Database
  ##
  #A system type
  class SystemType < Model
    has_many :systems

    validates_presence_of :name, :memory_stat_type

    ##
    #Maps memory stat type symbols to their enumerated values in the database
    MEMORY_STAT_TYPE = {unknown: 0, avg: 1, max: 2}

    ##
    #The inverse of MEMORY_STAT_TYPE
    MEMORY_STAT_TYPE_INVERSE = MEMORY_STAT_TYPE.invert

    ##
    #Finds a system type by name and memory stat type, creating it if it doesn't exist
    #
    #It is an error to attempt to create two types with the same name but different memory stat types.
    def self.find_or_create!(name, memory_stat_type)
      sys_type = SystemType.find_by(name: name)
      if sys_type
        unless sys_type.memory_stat_type == memory_stat_type
          type_code = MEMORY_STAT_TYPE[memory_stat_type]
          if type_code == nil
            raise "Unrecognized memory stat type '#{memory_stat_type}'"
          else
            raise "The recorded memory stat type for system type '#{name}' does not match the required type of #{type_code}"
          end
        end
      else
        sys_type = create!(name: name, memory_stat_type: memory_stat_type)
      end
      sys_type
    end

    ##
    #Returns the memory stat type as a symbol
    #
    #See Bookie::Database::MEMORY_STAT_TYPE for possible values.
    #
    #Based on http://www.kensodev.com/2012/05/08/the-simplest-enum-you-will-ever-find-for-your-activerecord-models/
    #
    #TODO: use nil as :unknown?
    def memory_stat_type
      type_code = read_attribute(:memory_stat_type)
      return nil if type_code == nil
      type = MEMORY_STAT_TYPE_INVERSE[type_code]
      raise "Unrecognized memory stat type code #{type_code}" unless type
      type
    end

    ##
    #Sets the memory stat type
    #
    #<tt>type</tt> should be a symbol.
    def memory_stat_type=(type)
      if type == nil
        write_attribute(:memory_stat_type, nil)
        return
      end
      type_code = MEMORY_STAT_TYPE[type]
      raise "Unrecognized memory stat type '#{type}'" unless type_code
      write_attribute(:memory_stat_type, type_code)
    end
  end
end
