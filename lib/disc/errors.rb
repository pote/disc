class Disc
  class Error < StandardError; end

  class UnknownJobClassError  < Error; end
  class NonParsableJobError   < Error; end
  class NonJobClassError      < Error; end
end
