class ProjectLocation < ActiveRecord::Base
  unloadable

  belongs_to :project_region,:class_name => 'ProjectRegion', :foreign_key => 'region_id'
  validates_presence_of :name, :region_id

  # before_destroy :validate_location

  def validate_location

    @projects= Project.where(:location_id=> self.id )

    errors.add(:location, " can not be delete, it's associated with projects.") if @projects.present?
  end

  def self.get_project_code
  	key = Redmine::Configuration['iserv_api_key']
    base_url = Redmine::Configuration['iserv_base_url']
    require 'json'
    require 'rest_client'
    url = base_url+"/services/projects/departments"
    begin
    	dept =	JSON.parse(RestClient::Request.new(:method => :get, :url => url, :headers => {:content_type => 'json',"Auth-key" => key}, :verify_ssl => false).execute.body)
    rescue Exception => e
		dept = []    	
    end
    #dept =	'[{ "name": "Admin", "department_code": "123"}, { "name": "BD", "department_code": "586ICU"}]'
    codes = []
    dept.each do |rec|
    	codes << [rec['name'],rec['department_code']]
    end
    codes
  end
end
