# frozen_string_literal: true

require 'inspec'
require 'json'

tfvars = JSON.parse(File.read('./' + ENV['PLATFORM_ENV'] + '.json'))

describe command('aws eks describe-cluster --name ' + tfvars['cluster_name']) do
  its('stdout') { should include ("\"name\": \"" + tfvars['cluster_name']) }          # exist
  its('stdout') { should include ("\"version\": \"" + "1.11") }    # have correct version, if specified
  its('stdout') { should include ("\"status\": \"ACTIVE\"") }                         # be active
end

describe command('aws autoscaling describe-auto-scaling-groups') do
  its('stdout') { should include ("\"AutoScalingGroupName\": \"" + tfvars['cluster_name'] + '-') }   # exist
  its('stdout') { should include ("\"LaunchConfigurationName\": \"" + tfvars['cluster_name'] + '-') }        # have correct launch config
end

describe command('aws autoscaling describe-launch-configurations') do
  its('stdout') { should include ("\"LaunchConfigurationName\": \"" + tfvars['cluster_name'] + '-') }  # exist
  its('stdout') { should include ("\"InstanceType\": \"" + "t2.xlarge") }                                     # have correct default instance
end
