%w( resource representation middleware ).each do |component|
  require File.join(File.expand_path(File.dirname(__FILE__)), 'ahora', component)
end