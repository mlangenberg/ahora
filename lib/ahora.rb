%w( resource representation ).each do |component|
  require File.join(File.expand_path(File.dirname(__FILE__)), 'ahora', component)
end