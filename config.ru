require_relative 'boot'
require_relative 'app'

Sourced::UI::Dashboard.configure do |config|
  config.header_links([
    { label: 'back to Coffee Shop', href: '/', url: false }
  ])
end

map '/sourced' do
  run Sourced::UI::Dashboard
end

map '/' do
  use Rack::Static, urls: ['/css', '/images', '/js'], root: 'public'
  run App
end
