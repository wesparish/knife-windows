#
# Author:: Adam Edwards (<adamed@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'
require 'tmpdir'

# These test cases exercise the Knife::Windows knife plugin's ability
# to download a bootstrap msi as part of the bootstrap process on
# Windows nodes. The test modifies the Windows batch file generated
# from an erb template in the plugin source in order to enable execution
# of only the download functionality contained in the bootstrap template.
# The test relies on knowledge of the fields of the template itself and 
# also on knowledge of the contents and structure of the Windows batch
# file generated by the template.
#
# Note that if the bootstrap template changes substantially, the tests
# should fail and will require re-implementation. If such changes
# occur, the bootstrap code should be refactored to explicitly expose
# the download funcitonality separately from other tasks to make the
# test more robust.
describe 'Knife::Windows::Core msi download functionality for knife Windows winrm bootstrap template' do 

  before(:all) do
    # All file artifacts from this test will be written into this directory
    @temp_directory = Dir.mktmpdir("bootstrap_test")

    # Location to which the download script will be modified to write
    # the downloaded msi
    @local_file_download_destination = "#{@temp_directory}/chef-client-latest.msi"
  end

  after(:all) do
    # Clear the temp directory upon exit
    if Dir.exists?(@temp_directory)
      FileUtils::remove_dir(@temp_directory)
    end
  end

  describe "running on any version of the Windows OS", :windows_only do
    before do
      @mock_bootstrap_context = Chef::Knife::Core::WindowsBootstrapContext.new({ }, nil, { })

      # Stub the bootstrap context and prevent config related sections
      # to be populated, chef installation and first chef run
      @mock_bootstrap_context.stub(:validation_key).and_return("echo.validation_key")
      @mock_bootstrap_context.stub(:encrypted_data_bag_secret).and_return("echo.encrypted_data_bag_secret")
      @mock_bootstrap_context.stub(:config_content).and_return("echo.config_content")
      @mock_bootstrap_context.stub(:start_chef).and_return("echo.echo start_chef_command")
      @mock_bootstrap_context.stub(:run_list).and_return("echo.run_list")
      @mock_bootstrap_context.stub(:install_chef).and_return("echo.echo install_chef_command")

      # Change the directorires where bootstrap files will be created
      @mock_bootstrap_context.stub(:bootstrap_directory).and_return(@temp_directory.gsub(::File::SEPARATOR, ::File::ALT_SEPARATOR))
      @mock_bootstrap_context.stub(:local_download_path).and_return(@local_file_download_destination.gsub(::File::SEPARATOR, ::File::ALT_SEPARATOR))

      # Prevent password prompt during bootstrap process
      @mock_winrm = Chef::Knife::Winrm.new
      @mock_winrm.stub(:get_password).and_return(nil)
      Chef::Knife::Winrm.stub(:new).and_return(@mock_winrm)

      Chef::Knife::Core::WindowsBootstrapContext.stub(:new).and_return(@mock_bootstrap_context)
    end

    it "downloads the chef-client MSI during winrm bootstrap" do
      clean_test_case

      bootstrap_context = Chef::Knife::BootstrapWindowsWinrm.new([ "127.0.0.1" ])

      # Execute the commands locally that would normally be executed via WinRM
      bootstrap_context.stub(:run_command) do |command|
        system(command)
      end

      bootstrap_context.run

      # Download should succeed
      download_succeeded?.should == true
    end
  end

  def download_succeeded?
    File.exists?(@local_file_download_destination) && ! File.zero?(@local_file_download_destination)
  end

  # Remove file artifiacts generated by individual test cases
  def clean_test_case
    if File.exists?(@local_file_download_destination)
      File.delete(@local_file_download_destination)
    end
  end
  
end 
