class Returner
  include Disc::Job

  def self.perform(argument)
    return argument
  end
end
