# -*- encoding: utf-8 -*-
# stub: bunny 2.6.3 ruby lib

Gem::Specification.new do |s|
  s.name = "bunny"
  s.version = "2.6.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Chris Duncan", "Eric Lindvall", "Jakub Stastny aka botanicus", "Michael S. Klishin", "Stefan Kaes"]
  s.date = "2017-01-19"
  s.description = "Easy to use, feature complete Ruby client for RabbitMQ 3.3 and later versions."
  s.email = ["michael.s.klishin@gmail.com"]
  s.extra_rdoc_files = ["README.md"]
  s.files = ["README.md"]
  s.homepage = "http://rubybunny.info"
  s.licenses = ["MIT"]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0")
  s.rubygems_version = "2.4.8"
  s.summary = "Popular easy to use Ruby client for RabbitMQ"

  s.installed_by_version = "2.4.8" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<amq-protocol>, [">= 2.0.1"])
    else
      s.add_dependency(%q<amq-protocol>, [">= 2.0.1"])
    end
  else
    s.add_dependency(%q<amq-protocol>, [">= 2.0.1"])
  end
end
