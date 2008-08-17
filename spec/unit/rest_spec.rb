#
# Author:: Adam Jacob (<adam@hjksolutions.com>)
# Copyright:: Copyright (c) 2008 HJK Solutions, LLC
# License:: GNU General Public License version 2 or later
# 
# This program and entire repository is free software; you can
# redistribute it and/or modify it under the terms of the GNU 
# General Public License as published by the Free Software 
# Foundation; either version 2 of the License, or any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

require File.expand_path(File.join(File.dirname(__FILE__), "..", "spec_helper"))
require 'uri'
require 'net/https'

describe Chef::REST, "initialize method" do
  it "should create a new Chef::REST" do
    Chef::REST.new("url").should be_kind_of(Chef::REST)
  end
end

describe Chef::REST, "get_rest method" do
  it "should create a url from the path and base url" do
    URI.should_receive(:parse).with("url/monkey")
    r = Chef::REST.new("url")
    r.stub!(:run_request)
    r.get_rest("monkey")
  end
  
  it "should call run_request :GET with the composed url object" do
    URI.stub!(:parse).and_return(true)
    r = Chef::REST.new("url")
    r.should_receive(:run_request).with(:GET, true, false, 10, false).and_return(true)
    r.get_rest("monkey")
  end
end

describe Chef::REST, "delete_rest method" do
  it "should create a url from the path and base url" do
    URI.should_receive(:parse).with("url/monkey")
    r = Chef::REST.new("url")
    r.stub!(:run_request)
    r.delete_rest("monkey")
  end
  
  it "should call run_request :DELETE with the composed url object" do
    URI.stub!(:parse).and_return(true)
    r = Chef::REST.new("url")
    r.should_receive(:run_request).with(:DELETE, true).and_return(true)
    r.delete_rest("monkey")
  end
end

describe Chef::REST, "post_rest method" do
  it "should create a url from the path and base url" do
    URI.should_receive(:parse).with("url/monkey")
    r = Chef::REST.new("url")
    r.stub!(:run_request)
    r.post_rest("monkey", "data")
  end
  
  it "should call run_request :POST with the composed url object and data" do
    URI.stub!(:parse).and_return(true)
    r = Chef::REST.new("url")
    r.should_receive(:run_request).with(:POST, true, "data").and_return(true)
    r.post_rest("monkey", "data")
  end
end

describe Chef::REST, "put_rest method" do
  it "should create a url from the path and base url" do
    URI.should_receive(:parse).with("url/monkey")
    r = Chef::REST.new("url")
    r.stub!(:run_request)
    r.put_rest("monkey", "data")
  end
  
  it "should call run_request :PUT with the composed url object and data" do
    URI.stub!(:parse).and_return(true)
    r = Chef::REST.new("url")
    r.should_receive(:run_request).with(:PUT, true, "data").and_return(true)
    r.put_rest("monkey", "data")
  end
end

describe Chef::REST, "run_request method" do
  before(:each) do
    @r = Chef::REST.new("url")
    @url_mock = mock("URI", :null_object => true)
    @url_mock.stub!(:host).and_return("one")
    @url_mock.stub!(:port).and_return("80")
    @url_mock.stub!(:path).and_return("/")
    @url_mock.stub!(:query).and_return("foo=bar")
    @url_mock.stub!(:scheme).and_return("https")
    @http_response_mock = mock("Net::HTTPSuccess", :null_object => true)
    @http_response_mock.stub!(:kind_of?).with(Net::HTTPSuccess).and_return(true)
    @http_response_mock.stub!(:body).and_return("ninja")
    @http_mock = mock("Net::HTTP", :null_object => true)
    @http_mock.stub!(:verify_mode=).and_return(true)
    @http_mock.stub!(:read_timeout=).and_return(true)
    @http_mock.stub!(:use_ssl=).with(true).and_return(true)
    @data_mock = mock("Data", :null_object => true)
    @data_mock.stub!(:to_json).and_return('{ "one": "two" }')
    @request_mock = mock("Request", :null_object => true)
    @request_mock.stub!(:body=).and_return(true)
    @request_mock.stub!(:method).and_return(true)
    @request_mock.stub!(:path).and_return(true)
    @http_mock.stub!(:request).and_return(@http_response_mock)
    @tf_mock = mock(Tempfile, { :puts => true, :close => true })
    Tempfile.stub!(:new).with("chef-rest").and_return(@tf_mock)
  end
  
  def do_run_request(method=:GET, data=false, limit=10, raw=false)
    Net::HTTP.stub!(:new).and_return(@http_mock)
    @r.run_request(method, @url_mock, data, limit, raw)
  end
  
  it "should raise an exception if the redirect limit is 0" do
    lambda { @r.run_request(:GET, "/", false, 0)}.should raise_error(ArgumentError)
  end
  
  it "should use SSL if the url starts with https" do
    @url_mock.should_receive(:scheme).and_return("https")
    @http_mock.should_receive(:use_ssl=).with(true).and_return(true)
    do_run_request
  end
  
  it "should set the OpenSSL Verify Mode to verify_none if requested" do
    @http_mock.should_receive(:verify_mode=).and_return(true)
    do_run_request
  end
  
  it "should set a read timeout based on the rest_timeout config option" do
    Chef::Config[:rest_timeout] = 10
    @http_mock.should_receive(:read_timeout=).with(10).and_return(true)
    do_run_request
  end
  
  it "should build a new HTTP GET request" do
    Net::HTTP::Get.should_receive(:new).with("/?foo=bar", 
      { 'Accept' => 'application/json' }
    ).and_return(@request_mock)
    do_run_request
  end
  
  it "should build a new HTTP POST request" do
    Net::HTTP::Post.should_receive(:new).with("/", 
      { 'Accept' => 'application/json', "Content-Type" => 'application/json' }
    ).and_return(@request_mock)
    do_run_request(:POST, @data_mock)
  end
  
  it "should build a new HTTP PUT request" do
    Net::HTTP::Put.should_receive(:new).with("/", 
      { 'Accept' => 'application/json', "Content-Type" => 'application/json' }
    ).and_return(@request_mock)
    do_run_request(:PUT, @data_mock)
  end
  
  it "should build a new HTTP DELETE request" do
    Net::HTTP::Delete.should_receive(:new).with("/?foo=bar", 
      { 'Accept' => 'application/json' }
    ).and_return(@request_mock)
    do_run_request(:DELETE)
  end
  
  it "should raise an error if the method is not GET/PUT/POST/DELETE" do
    lambda { do_run_request(:MONKEY) }.should raise_error(ArgumentError)
  end
  
  it "should run an http request" do
    @http_mock.should_receive(:request).and_return(@http_response_mock)
    do_run_request
  end
  
  it "should return the body of the response on success" do
    do_run_request.should eql("ninja")
  end
  
  it "should inflate the body as to an object if JSON is returned" do
    @http_response_mock.stub!(:[]).with('content-type').and_return("application/json")
    JSON.should_receive(:parse).with("ninja").and_return(true)
    do_run_request
  end
  
  it "should call run_request again on a Redirect response" do
    @http_response_mock.stub!(:kind_of?).with(Net::HTTPSuccess).and_return(false)
    @http_response_mock.stub!(:kind_of?).with(Net::HTTPRedirection).and_return(true)
    @http_response_mock.stub!(:[]).with('location').and_return(@url_mock.path)
    lambda { do_run_request(method=:GET, data=false, limit=1) }.should raise_error(ArgumentError)
  end
  
  it "should raise an exception on an unsuccessful request" do
    @http_response_mock.stub!(:kind_of?).with(Net::HTTPSuccess).and_return(false)
    @http_response_mock.stub!(:kind_of?).with(Net::HTTPRedirection).and_return(false)
    @http_response_mock.should_receive(:error!)
    do_run_request
  end
  
  it "should build a new HTTP GET request without the application/json accept header for raw reqs" do
    Net::HTTP::Get.should_receive(:new).with("/?foo=bar", {}).and_return(@request_mock)
    do_run_request(:GET, false, 10, true)
  end
  
  it "should create a tempfile for the output of a raw request" do
    Tempfile.should_receive(:new).with("chef-rest").and_return(@tf_mock)
    do_run_request(:GET, false, 10, true).should eql(@tf_mock)    
  end
  
  it "should populate the tempfile with the value of the raw request" do
    @tf_mock.should_receive(:puts, "ninja").once.and_return(true)
    do_run_request(:GET, false, 10, true)
  end
  
  it "should close the tempfile if we're doing a raw request" do
    @tf_mock.should_receive(:close).once.and_return(true)
    do_run_request(:GET, false, 10, true)
  end

end