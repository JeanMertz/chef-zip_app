#
# Cookbook Name:: zip_app
# Provider:: package
#
# Copyright 2011, Fletcher Nichol
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

def load_current_resource
  @zip_pkg = Chef::Resource::ZipAppPackage.new(new_resource.name)
  @zip_pkg.app(new_resource.app)
  Chef::Log.debug("Checking for application #{new_resource.app}")

  # Set extension
  new_resource.extension(new_resource.extension ? ".#{new_resource.extension}" : '')

  # Set correct destination based on extension
  case new_resource.extension
  when ".prefPane"
    new_resource.destination(::File.expand_path('~/Library/PreferencePanes')) if new_resource.destination == '/Applications'
  else
    new_resource.destination(::File.expand_path(new_resource.destination))
  end

  # Set installed flag
  if new_resource.installed_resource
    installed = ::File.exist?(new_resource.installed_resource)
  else
    installed = ::File.exist?("#{::File.expand_path(new_resource.destination)}/#{new_resource.app}#{new_resource.extension}")
  end
  @zip_pkg.installed(installed)
end

action :install do
  unless @zip_pkg.installed
    zip_file = new_resource.zip_file || new_resource.source.split('/').last
    downloaded_file = "#{Chef::Config[:file_cache_path]}/#{zip_file}"

    if new_resource.source =~ /^(https?|ftp|git):\/\/.+$/i
      remote_file downloaded_file do
        source new_resource.source
        checksum new_resource.checksum if new_resource.checksum
      end
    elsif new_resource.source
      cookbook_file downloaded_file do
        source new_resource.source
        checksum new_resource.checksum if new_resource.checksum
      end
    end

    ruby_block "Extract #{new_resource.app}" do
      block do
        tmp = Chef::Config[:file_cache_path]

        # Unzip
        %x[unzip -qq '#{downloaded_file}' -d #{tmp}]

        # Install application
        case new_resource.extension
        when ".mpkg"
          %x[sudo installer -pkg #{tmp}/#{new_resource.app}.mpkg -target /]
        when ".prefPane"
          FileUtils.cp_r "#{tmp}/#{new_resource.app}#{new_resource.extension}", new_resource.destination
        else
          FileUtils.cp_r "#{tmp}/#{new_resource.app}#{new_resource.extension}", new_resource.destination
        end
      end
    end
  end
end
