#
# Cookbook Name:: wordpress
# Recipe:: install-theme
#

include_recipe 'deploy'

node[:deploy].each do |application, deploy|
  Chef::Log.info("Deploy for #{application} as #{deploy[:application_type]}...")

  if deploy[:application_type] != 'other'
    Chef::Log.debug("Skipping deploy::other application #{application} as it is not configuration or themes")
    next
  end

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end
end