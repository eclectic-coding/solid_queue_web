require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "solid_queue"
require "pagy"
require "pagy/toolbox/paginators/method"
require "turbo-rails"

module SolidQueueWeb
  class Engine < ::Rails::Engine
    isolate_namespace SolidQueueWeb

    config.i18n.load_path += Gem.find_files("pagy/locales/en.yml")
    config.i18n.load_path += Dir[root.join("config/locales/*.yml").to_s]

    initializer "solid_queue_web.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app/javascript")
      end
    end

    initializer "solid_queue_web.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb")
        app.config.importmap.cache_sweepers << root.join("app/javascript")
      end
    end

    initializer "solid_queue_web.pagy" do |app|
      app.config.after_initialize do
        Pagy::OPTIONS[:limit] = SolidQueueWeb.page_size
      end
    end
  end
end
