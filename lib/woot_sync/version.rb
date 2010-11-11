require 'pathname'

module WootSync
  module VERSION
    MAJOR, MINOR, TINY = begin
      load_path = Pathname.new(File.dirname(__FILE__)).join('../../VERSION')
      load_path.read.split('.').map { |s| s.to_i }
    rescue
      [0, 0, 0]
    end

    STRING = [MAJOR, MINOR, TINY].join('.')
  end
end
