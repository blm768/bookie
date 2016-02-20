module FormatterHelpers
  class IOMock
    def initialize
      @buf = ""
    end

    def puts(str)
      @buf << str.to_s
      @buf << "\n"
    end

    def write(str)
      @buf << str.to_s
    end

    def printf(format, *args)
      @buf << sprintf(format, *args)
    end

    def buf
      @buf
    end
  end
end
