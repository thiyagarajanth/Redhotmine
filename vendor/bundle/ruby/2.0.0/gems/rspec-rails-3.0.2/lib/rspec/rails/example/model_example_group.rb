module RSpec::Rails
  # Container class for model spec functionality. Does not provide anything
  # special over the common RailsExampleGroup currently.
  module ModelExampleGroup
    extend ActiveSupport::Concern
    include RSpec::Rails::RailsExampleGroup
  end
end
