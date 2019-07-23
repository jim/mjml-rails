require "rails/version"
require "action_view"
require "action_view/template"
require "mjml/mjmltemplate"
require "mjml/railtie"
require "rubygems"

module Mjml
  mattr_accessor :template_language, :raise_render_exception, :mjml_binary_version_supported, :mjml_binary_error_string, :beautify, :minify, :mjml_path

  @@template_language = :erb
  @@raise_render_exception = true
  @@mjml_binary_version_supported = "4."
  @@mjml_binary_error_string = "Couldn't find the MJML #{Mjml.mjml_binary_version_supported} binary. Have you run $ yarn add mjml?"
  @@beautify = true
  @@minify = false

  # Check if the mjml binaray at the provided path is the correct version
  def self.check_version(path)
    output, status = Open3.capture2(path, '--version')
    status.success? && output.include?("mjml-core: #{Mjml.mjml_binary_version_supported}")
  rescue Errno::ENOENT
    return false
  end

  # Check if mjml exists and is the correct version at path
  # If it is, set the value to Mjml.mjml_path
  def self.try_path(path)
    return false unless path && check_version(path)
    Mjml.mjml_path = path
    logger.info "Using mjml binary at #{path}"
  end

  def self.configure_mjml_path!
    if Mjml.mjml_path
      return if try_path(Mjml.mjml_path) 
      raise "mjml at #{Mjml.mjml_path} is wrong version"
    end

    # Check for a global install of MJML binary
    return if try_path('mjml')

    # Check for a local install of MJML binary
    output, status = Open3.capture2("yarn bin mjml")
    return if status.success? && try_path(output.chomp)
  
    raise Mjml.mjml_binary_error_string
  end

  class Handler
    def template_handler
      @_template_handler ||= ActionView::Template.registered_template_handler(Mjml.template_language)
    end

    # Optional second source parameter to make it work with Rails >= 6:
    # Beginning with Rails 6 template handlers get the source of the template as the second
    # parameter.
    def call(template, source = nil)
      compiled_source =
        if Rails::VERSION::MAJOR >= 6
          template_handler.call(template, source)
        else
          template_handler.call(template)
        end

      # Per MJML v4 syntax documentation[0] valid/render'able document MUST start with <mjml> root tag
      # If we get here and template source doesn't start with one it means
      # that we are rendering partial named according to legacy naming convention (partials ending with '.mjml')
      # Therefore we skip MJML processing and return raw compiled source. It will be processed
      # by MJML library when top-level layout/template is rendered
      #
      # [0] - https://github.com/mjmlio/mjml/blob/master/doc/guide.md#mjml
      if compiled_source =~ /<mjml(.+)?>/i
        "Mjml::Mjmltemplate.to_html(begin;#{compiled_source};end).html_safe"
      else
        compiled_source
      end
    end
  end

  def self.setup
    yield self if block_given?
  end

  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.progname = self.name
      end
    end
  end
end
