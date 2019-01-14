# frozen_string_literal: true

require 'awspec'
require 'json'

tfvars = JSON.parse(File.read('./' + ENV['PLATFORM_ENV'] + '.json'))

describe security_group(tfvars['cluster_name'] + '_eks_cluster_sg') do
  it { should exist }
  its(:vpc_id) { should eq tfvars['cluster_vpc_id'] }
  its(:outbound) { should be_opened }
  its(:inbound) { should be_opened(443).protocol('tcp').for(tfvars['cluster_name'] + '_eks_worker_sg') }
  it { should have_tag('pipeline').value('feedyard/tf-aws-platform-eks') }
end

describe security_group(tfvars['cluster_name'] + '_eks_worker_sg') do
  it { should exist }
  its(:vpc_id) { should eq tfvars['cluster_vpc_id'] }
  its(:outbound) { should be_opened }
  its(:inbound) { should be_opened(443).protocol('tcp').for(tfvars['cluster_name'] + '_eks_cluster_sg') }
  it { should have_tag('kubernetes.io/cluster/' + tfvars['cluster_name']).value('shared') }
  it { should have_tag('pipeline').value('feedyard/tf-aws-platform-eks') }
end
