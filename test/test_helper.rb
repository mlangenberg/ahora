def fake_http(path, body)
  FakeWeb.register_uri :get, uri(path), :body => body
end

def uri(path)
  'http://user:pass@test.net' + path
end

def fixture(name)
  File.open File.join(File.dirname('__FILE__'), 'test', 'fixtures', "#{name}.xml")
end