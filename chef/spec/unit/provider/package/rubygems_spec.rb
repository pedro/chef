#
# Author:: David Balatero (dbalatero@gmail.com)
#
# Copyright:: Copyright (c) 2009 David Balatero 
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "spec_helper"))

describe Chef::Provider::Package::Rubygems, "gem_binary_path" do
  before(:each) do
    @node = mock("Chef::Node", :null_object => true)
    @new_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "rspec",
      :version => "1.2.2",
      :package_name => "rspec",
      :updated => nil,
      :gem_binary => nil
    )
    @provider = Chef::Provider::Package::Rubygems.new(@node, @new_resource)
    @exit = mock('popen4 exit', :exitstatus => 0)
  end

  it "should return a relative path to gem if no gem_binary is given" do
    @provider.gem_binary_path.should eql("gem")
  end

  it "should return a specific path to gem if a gem_binary is given" do
    @new_resource.should_receive(:gem_binary).and_return("/opt/local/bin/custom/ruby")
    @provider.gem_binary_path.should eql("/opt/local/bin/custom/ruby")
  end

  it "parses the gem list output to check what gems/versions are on the system" do
    stdout = "*** LOCAL GEMS ***\n\nhpricot (0.8.1)\nthin (1.2.2, 1.0.1, 1.0.0)"
    Chef::Mixin::Command.should_receive(:popen4).with("gem list --local").and_yield(123, 'stdin', stdout, 'stderr').and_return(@exit)
    @provider.class.version_for('gem', 'chef').should be_nil
    @provider.class.version_for('gem', 'hpricot').should == ['0.8.1']
    @provider.class.version_for('gem', 'thin').should == ['1.2.2', '1.0.1', '1.0.0']
  end

  it "parses the gem install output to check which gems were installed, and save those in the class cache" do
    stdout = "Successfully installed chef-0.7.5\nSuccessfully installed json-1.1.7\n2 gems installed"
    @provider.should_receive(:popen4).and_yield(123, 'stdin', stdout, 'stderr').and_return(@exit)
    @provider.install_package('chef', '0.7.5')
    @provider.class.version_for('gem', 'chef').should == ['0.7.5']
    @provider.class.version_for('gem', 'json').should == ['1.1.7']
  end

  it "removes the cache entry together with the gem" do
    @provider.class.stub!(:versions).and_return 'gem' => { 'thin' => ['1.2.2', '1.0.1', '1.0.0'] }
    @provider.should_receive(:run_command)
    @provider.remove_package('thin', '1.0.1')
    @provider.class.version_for('gem', 'thin').should == ['1.2.2', '1.0.0']
  end

  it "removes all versions from the cache when no specific version is set" do
    @provider.class.stub!(:versions).and_return 'gem' => { 'thin' => ['1.2.2', '1.0.1', '1.0.0'] }
    @provider.should_receive(:run_command)
    @provider.remove_package('thin', nil)
    @provider.class.version_for('gem', 'thin').should be_nil
  end
end
