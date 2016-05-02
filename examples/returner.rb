class Returner
  include Disc::Job

  def perform(argument)
    return argument
  end
end
