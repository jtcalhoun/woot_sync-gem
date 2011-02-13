module WootSync

  def self.load_settings!
    WootSync::Base.configure do |base|
      begin
        require 'erb'

        load_path = File.expand_path('../../../config/settings.yml', __FILE__)

        (YAML::load(ERB.new(IO.read(load_path)).result) || {}).each do |k,v|
          base.send("#{k}=", v)
        end
      rescue Errno::ENOENT
        warn 'WARNING: could not load WootSync settings file'
      end

      base.logger ||= Logger.new(STDOUT)
    end
  end

  if defined?(Rails::Railtie)
    class Railtie < Rails::Railtie
      config.woot_sync = ActiveSupport::OrderedOptions.new

      initializer 'woot_sync.load_settings' do |app|
        WootSync.load_settings!
        app.config.woot_sync.each { |k,v| WootSync::Base.send("#{k}=", v) }
      end

      initializer 'woot_sync.logger', :after => 'woot_sync.load_settings' do
        WootSync::Base.logger = Rails.logger
      end
    end

  else
    WootSync.load_settings!
  end
end
