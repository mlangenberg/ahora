%w( last_modified_caching request_logger ).each do |component|
  require File.join(File.expand_path(File.dirname(__FILE__)), 'middleware', component)
end