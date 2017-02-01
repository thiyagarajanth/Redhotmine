Redmine::Plugin.register :inia_services do
  name 'Inia Services plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
end


Rails.configuration.to_prepare do
  # require 'bunny'
  # helper = Object.new.extend(IniaServiceHelper)
  # connection = Bunny.new(:host => Redmine::Configuration['rabbitmq_ip'], :user => Redmine::Configuration['rabbitmq_user'], :password => Redmine::Configuration['rabbitmq_pwd'])
  # connection.start
  # ch = connection.create_channel
  # q = ch.queue("a.pto")
  # q.subscribe(:consumer_tag => "unique_consumer") do | delivery_info,properties, payload|
  #   p '=====as==========='
  #   param = JSON.parse(payload)
  #   p '===================calles===============asasas========='
  #   # param = {"employeeId"=>"5046", "fromDate"=>"2017-01-12", "toDate"=>"2017-01-12", "leaveDays"=>"1", "leaveType"=>"PL", "leaveCategory"=>"Leave", "leaveDescription"=>"Test12", "leaveDuration"=>"Full day", "leaveStatus"=>"Approved", "leaveHours"=>""}
  #   helper.create_ptos_from_mq(param)
  # end


end