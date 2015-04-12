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

    if defined?(deploy[:application_type]) && deploy[:application_type] != 'php'
        Chef::Log.debug("Skipping WP Configure  application #{app_name} as it is not defined as php wp")
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


	# Import Wordpress database backup from file if it exists
	mysql_command = "/usr/bin/mysql -h #{deploy[:database][:host]} -u #{deploy[:database][:username]} -p#{deploy[:database][:password]}  #{deploy[:database][:database]}"

    if defined?(node["restore_wp_database"]) && node["restore_wp_database"].to_s == "true"
	    Chef::Log.info("RESTORING Wordpress database backup... (restore_wp_databse variable set on deploy json)")
        Chef::Log.info("restore cmd: #{mysql_command} < #{deploy[:deploy_to]}/current/*.sql;")
        script "restore_database" do
            interpreter "bash"
            user "root"
            cwd "#{deploy[:deploy_to]}/current/"
            code <<-EOH
                if ls #{deploy[:deploy_to]}/current/*.sql &> /dev/null; then
                    #{mysql_command} < #{deploy[:deploy_to]}/current/*.sql;
                    mv #{deploy[:deploy_to]}/current/*.sql /root/;
                    echo "Restore done";
                fi;
            EOH
        end
    else
        Chef::Log.info("Not importing wordpress database backup. Set variable restore_wp_database=true in your deploy json, if you want to restore DB from backup")
        script "move_sql" do
            interpreter "bash"
            user "root"
            cwd "#{deploy[:deploy_to]}/current/"
            code <<-EOH
                if ls #{deploy[:deploy_to]}/current/*.sql &> /dev/null; then
                    mv #{deploy[:deploy_to]}/current/*.sql /root/;
                fi;
            EOH
        end
    end

    # Create a Cronjob for Wordpress
    domain = deploy[:domains].first
    command = "wget --http-user=demo --http-passwd=demo -q -O - http://#{domain}/wp-cron.php?doing_wp_cron >/dev/null 2>&1"
    cron "wordpress-#{app_name}" do
        hour "*"
        minute "*/15"
        weekday "*"
        command command
    end
end

