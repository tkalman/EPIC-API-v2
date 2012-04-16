#\ --port 9292
=begin License
Copyright ©2011-2012 Pieter van Beek <pieterb@sara.nl>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
=end
# This is the default configuration file for the +rackup+ command.

# +epic.rb+ is the top level include file for the EPIC web service.
# All other necessary files are included from there.
require './epic.rb'

# The default configuration uses Rack::Chunked to allow streaming of response
# bodies. Using this middleware, we don't have to specify a +Content-Length+
# header.
require 'rack/chunked'

# This middleware is only used during development, and should be disabled in
# production services. It checks if the source code has changed since the last
# request, and reloads the new source code when needed.
#
# This works _most_ of the time, but can lead to unexpected results too...
# If you're debugging the service, make sure you don't accidentally chase
# phantom bugs introduced by dynamically reloading source files!
require 'rack/reloader'

# Perform header spoofing.
#
# This allows users to provide HTTP headers in query parameters to the service.
# This can be handy when you're using a web browser to contact the service.
# For example, to retrieve a JSON response instead of the "default" XHTML, you'd
# normally send an +Accept:+ request header.
#
# With the following middleware in place, you can also append
# +?_http_accept=application/json+ to the URL.
use Rack::Config do |env|
  raise 'Multithreaded web servers are not supported' if env['rack.multiprocess']
  req = Rack::Request.new env
  req.GET.each do |k, v|
    if %r{\A_http_(\w+)\z}i.match(k)
      env["HTTP_#{$1.upcase}"] = v.to_s
    end
  end
end

# Allow streaming:
use Rack::Chunked

# Dynamically reload source files when they've changed. This line should
# probably be commented out in production services.
use Rack::Reloader, 1

# Check the documentation. This is just an optional bit of optimization.
use Rack::Sendfile

# Some parts of the namespace are not dynamically generated from ruby scripts,
# but just served statically from the filesystem.
# This includes stuff like CSS files, the favicon etc.
use Rack::Static,
  :urls  => ['/inc/', '/favicon.ico', '/docs/', %r{/(templates|profiles)/\d+/.+}],
  :root  => 'public',
  :index => nil

# This middleware allows our web service to provide _relative_ _URI's_ in the
# +Location:+ response header. According to RFC2616 (HTTP/1.1) only absolute
# URI's are allowed. This middleware translates our relative URI's to absolute
# URI's, given the request path.
#
# Warning: The web service depends on this middleware being present!
use Djinn::RelativeLocation

# As said, the distribution comes with HTTP Digest authentication preconfigured.
use Rack::Auth::Digest::MD5, {
    :realm => EPIC::REALM, :opaque => EPIC::OPAQUE, :passwords_hashed => true
  } do
  |username|
  username = username.to_str
  EPIC::USERS[username] ? EPIC::USERS[username][:digest] : nil
end

# And finally, let's start the actual web service:
run Djinn::RESTServer.new( EPIC::ResourceFactory.instance )