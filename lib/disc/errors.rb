class Disc
  class UnknownJobClassError < StandardError; end
  class NonSerializableJobError < StandardError; end
  class NonParsableJobError < StandardError; end
end
