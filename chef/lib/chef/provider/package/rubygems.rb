#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
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

require 'chef/provider/package'
require 'chef/mixin/command'
require 'chef/resource/package'

class Chef
  class Provider
    class Package
      class Rubygems < Chef::Provider::Package  
      
        def self.versions
          @@versions ||= {}
        end
      
        def self.version_for(gem_binary_path, gem_name)
          versions[gem_binary_path] ||= gem_list_parse(gem_binary_path)
          versions[gem_binary_path][gem_name]
        end
      
        def self.gem_list_parse(gem_binary_path)
          gems = {}
          status = Chef::Mixin::Command.popen4("#{gem_binary_path} list --local") do |pid, stdin, stdout, stderr|
            stdout.each do |line|
              name, versions = gem_line_parse(line)
              gems[name] = versions if name
            end
          end
          unless status.exitstatus == 0
            raise Chef::Exceptions::Package, "#{gem_binary_path} list --local failed - #{status.inspect}!"
          end
          gems
        end
      
        def self.gem_line_parse(line)
          if line =~ /(.*) \((.*)\)/
            return $1, $2.split(', ')
          end
        end
      
        def gem_list_parse(line)
          installed_versions = Array.new
          if line.match("^#{@new_resource.package_name} \\((.+?)\\)$")
            installed_versions = $1.split(/, /)
            installed_versions
          else
            nil
          end
        end

        def gem_binary_path
          path = @new_resource.gem_binary
          path ? path : 'gem'
        end
      
        def load_current_resource
          @current_resource = Chef::Resource::Package.new(@new_resource.name)
          @current_resource.package_name(@new_resource.package_name)
          @current_resource.version(nil)
        
          # First, we need to look up whether we have the local gem installed or not
          if installed_versions = self.class.version_for(gem_binary_path, @new_resource.package_name)
            if installed_versions.detect { |v| v == @new_resource.version }
              Chef::Log.debug("#{@new_resource.package_name} at version #{@new_resource.version}")
              @current_resource.version(@new_resource.version)
            else
              iv = installed_versions.first
              Chef::Log.debug("#{@new_resource.package_name} at version #{iv}")
              @current_resource.version(iv)
            end
          end
          
          @current_resource
        end

        def candidate_version
          return @candidate_version if @candidate_version

          status = popen4("#{gem_binary_path} list --remote #{@new_resource.package_name}#{' --source=' + @new_resource.source if @new_resource.source}") do |pid, stdin, stdout, stderr|
            stdout.each do |line|
              installed_versions = gem_list_parse(line)
              next unless installed_versions
              Chef::Log.debug("candidate_version: remote rubygem(s) available: #{installed_versions.inspect}")
              
              unless installed_versions.empty?
                Chef::Log.debug("candidate_version: setting install candidate version to #{installed_versions.first}")
                @candidate_version = installed_versions.first
              end
            end

          end

          unless status.exitstatus == 0
            raise Chef::Exceptions::Package, "#{gem_binary_path} list --remote failed - #{status.inspect}!"
          end
          @candidate_version
        end
      
        def install_package(name, version)
          src = nil
          if @new_resource.source
            src = "  --source=#{@new_resource.source} --source=http://gems.rubyforge.org"
          end  
          run_command(
            :command => "#{gem_binary_path} install #{name} -q --no-rdoc --no-ri -v #{version}#{src}"
          )
          self.class.versions[gem_binary_path][name] ||= []
          self.class.versions[gem_binary_path][name] << version
        end
      
        def upgrade_package(name, version)
          install_package(name, version)
        end
      
        def remove_package(name, version)
          if version
            run_command(
              :command => "#{gem_binary_path} uninstall #{name} -q -v #{version}"
            )
            if self.class.versions[gem_binary_path][name]
              self.class.versions[gem_binary_path][name].delete(version)
            end
          else
            run_command(
              :command => "#{gem_binary_path} uninstall #{name} -q -a"
            )
            self.class.versions[gem_binary_path].delete(name)
          end
        end
      
        def purge_package(name, version)
          remove_package(name, version)
        end
      
      end
    end
  end
end
