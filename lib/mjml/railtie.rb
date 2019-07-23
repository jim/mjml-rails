module Mjml
  class Railtie < Rails::Railtie
    config.mjml = Mjml
    config.app_generators.mailer :template_engine => :mjml

    initializer "mjml-rails.register_template_handler" do
      ActionView::Template.register_template_handler :mjml, Mjml::Handler.new
      Mime::Type.register_alias "text/html", :mjml
    end

    initializer "mjml-rails.configure_mjml_path", after: "load_config_initializers" do
      Mjml.configure_mjml_path!
    end
  end
end
