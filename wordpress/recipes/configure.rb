# AWS OpsWorks Recipe for Wordpress to be executed during the Configure lifecycle phase
# - Creates the config file wp-config.php with MySQL data.

require 'uri'
require 'net/http'
require 'net/https'

uri = URI.parse("https://api.wordpress.org/secret-key/1.1/salt/")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
request = Net::HTTP::Get.new(uri.request_uri)
response = http.request(request)
keys = response.body


# Create the Wordpress config file wp-config.php with corresponding values
node[:deploy].each do |app_name, deploy, application, wp|
    Chef::Log.info("Considering configuring WP app #{app_name} via #{deploy[:domains]}...")

    if !defined?(deploy[:domains])
        Chef::Log.info("Skipping WP Configure for #{app_name} (no domains defined)")
        next
    end

    template "#{deploy[:deploy_to]}/current/wp-config.php" do
        source "wp-config.php.erb"
        mode 0660
        group deploy[:group]

        if platform?("ubuntu")
          owner "www-data"
        elsif platform?("amazon")
          owner "apache"
        end

        variables(
            :database   => (deploy[:database][:database] rescue nil),
            :user       => (deploy[:database][:username] rescue nil),
            :password   => (deploy[:database][:password] rescue nil),
            :host       => (deploy[:database][:host] rescue nil),
            :keys       => (keys rescue nil),
            :domain     => (deploy[:domains].first)
        )
    end


    site = deploy[:application]
    siteSettings = node[:wp]["#{site}"]

    if siteSettings.nil?
        Chef::Log.info("Missing WordPress stack configuration for #{site}, not found in:")
        Chef::Log.info(node[:wp].to_json)
        next
    end

    Chef::Log.info("Looking for theme for #{site}")

    theme = siteSettings[:theme]
    moduleBase = "/srv/www"
    themeBase = "#{moduleBase}/#{theme}/current"
    siteBase = "#{deploy[:deploy_to]}/current"

    unless theme.nil?

        Chef::Log.info("Installing theme from #{themeBase}")
        Chef::Log.info("Installing theme to #{siteBase}")

        bash "install_theme_and_plugins" do
            user "deploy"
            group "apache"
            code <<-EOH
              ln -s "#{themeBase}/themes/*" "#{siteBase}/themes/"
              ln -s "#{themeBase}/plugins/*" "#{siteBase}/plugins/"

    #              chmod -R 775 "#{siteBase}/plugins/"
    #              chmod -R 775 "#{siteBase}/themes/"
            EOH
        end
    end
end

