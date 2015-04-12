# AWS OpsWorks Recipe for Wordpress to be executed during the Configure lifecycle phase
# - Creates the config file wp-config.php with MySQL data.
# - Creates a Cronjob.
# - Imports a database backup if it exists.

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
node[:deploy].each do |app_name, deploy|
    Chef::Log.info("Configuring WP app #{app_name}...")
Chef::Log.info(deploy.to_json)
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


Chef::Log.info("Short name: #{node[:appshortname]}")
Chef::Log.info("Theme name: #{node[:appshortname][:theme_app]}")

    if defined?(node[:appshortname])

        theme = node[:appshortname][:theme_app]
        moduleBase = "/srv/www"
        themeBase = "#{moduleBase}/#{node[:appshortname]}/current"
        siteBase = "#{deploy[:deploy_to]}/current"

Chef::Log.info("Theme base: #{themeBase}")

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

