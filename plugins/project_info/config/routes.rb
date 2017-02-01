# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
match '/projects_locations', :to => 'project_location_setup#locations_list', :as => 'projects_location_list', :via => [:get]

match '/projects_locations/new', :to => 'project_location_setup#new', :as => 'projects_location_new', :via => [:get]
match '/projects_locations/edit', :to => 'project_location_setup#edit', :as => 'projects_location_edit', :via => [:get]
match '/projects_locations/create', :to => 'project_location_setup#create', :as => 'projects_location_edit', :via => [:post]
match '/projects_locations/update', :to => 'project_location_setup#update', :as => 'projects_location_update', :via => [:put,:post]
match '/projects_locations/delete', :to => 'project_location_setup#destroy', :as => 'projects_location_delete', :via => [:get,:delete]
match '/get_project_locations', :to => 'project_location_setup#get_project_locations', :as => 'get_project_locations', :via => [:post]


match '/projects_regions', :to => 'project_region_setup#regions_list', :as => 'projects_region_list', :via => [:get]
match '/projects_regions/new', :to => 'project_region_setup#new', :as => 'projects_region_new', :via => [:get]
match '/projects_regions/edit', :to => 'project_region_setup#edit', :as => 'projects_region_edit', :via => [:get]
match '/projects_regions/create', :to => 'project_region_setup#create', :as => 'projects_region_edit', :via => [:post]
match '/projects_regions/update', :to => 'project_region_setup#update', :as => 'projects_region_update', :via => [:put,:post]
match '/projects_regions/delete', :to => 'project_region_setup#destroy', :as => 'projects_region_delete', :via => [:delete]

match '/services/append_members', :to => 'services#append_members', :as => 'append_members', :via => [:post,:get, :put]
match '/services/billable_statuses', :to => 'services#billable_statuses', :via => [:post,:put]
match '/services/inia_access', :to => 'services#inia_access_for_users',:via => [:post,:put]
match '/services/billingtype/:name', :to => 'services#billingtype', :via => [:get]
match '/services/employee-cost-report', :to => 'services#employee_cost_report', :as => '/services/employee_cost_report', :via => [:get]
match '/services/epup-dashboard/:engagement', :to => 'services#epup_dashboard', :as => '/services/epup_dashboard', :via => [:get]
match '/services/flexioff', :to => 'services#epup_dashboard', :as => '/services/epup_dashboard', :via => [:post, :get]
match '/services/flexioffreport', :to => 'services#flexi_off_report', :via => [:get,:post]
match '/services/projectflexihours', :to => 'services#get_project_flexi_hours', :via => [:get,:post]
match '/services/employee-resource-info', :to => 'services#get_resource_by_employee_id', :via => [:get,:post]
match '/services/resources-info', :to => 'services#get_resource_info', :via => [:get,:post]
match '/services/get-projects-list', :to => 'services#get_project_list', :via => [:get,:post]