if defined?(ActiveAdmin) && defined?(Wordpress::Blog)
    ActiveAdmin.register Wordpress::Blog, as: "Blog" do
        init_controller 
        
        permit_params  :locale_id,  :name , :description , :cloudflare_id, :domain_id, :admin_user_id, :cname, :use_ssl, :migration
        menu priority: 5
        active_admin_paranoia 
         
        # state_action :processed
        state_action :has_done
        state_action :publish  
        

        # Scope
        scope :pending
        scope :installed
        scope :processing
        scope :done
        scope :published
        scope :published_today
        scope :published_month

        
        controller do
            def new
                if Server.active.size.blank? || Cloudflare.active.size == 0
                    options = { alert: I18n.t('active_admin.check_server_and_cloudflare',  default: "无可用服务器或者Cloudflare") }
                    redirect_back({ fallback_location: ActiveAdmin.application.root_to }.merge(options)) 
                else
                    super
                end 
            end
            def create   
                params[:blog][:admin_user_id] = current_admin_user.id
                super 
            end

            def scoped_collection
                if current_admin_user.admin?
                    super
                else
                    end_of_association_chain.where(admin_user_id: current_admin_user.id) 
                end
            end
        end 

        ## Member actions
        member_action :set_dns, method: :put do   
            begin
                resource.set_dns 
                options = { notice: I18n.t('active_admin.set_dns',  default: "设置成功") }
            rescue Exception  => e   
                options = { alert: e.message }
            end 
            redirect_back({ fallback_location: ActiveAdmin.application.root_to }.merge(options)) 
        end

        member_action :reset_password, method: :put do   
            resource.reset_password 
            options = { notice: I18n.t('active_admin.reset_password',  default: "Reset Password: Processing") }
            redirect_back({ fallback_location: ActiveAdmin.application.root_to }.merge(options)) 
        end 

        member_action :login, method: :put do   
            render "admin/blogs/login.html.erb" , locals: { blog_url: resource.cloudflare_origin, user: resource.user , password: resource.password } 
        end

        member_action :install, method: :put do  
            if resource.pending? 
                if resource.templates.size > 1
                    render "admin/blogs/install"  
                elsif  resource.templates.size == 1
                    resource.install_with_template
                    options = { alert: I18n.t('active_admin.installing',  default: "正在安装") }
                    redirect_back({ fallback_location: ActiveAdmin.application.root_to }.merge(options)) 
                else
                    options = { alert: I18n.t('active_admin.none_template', lang:  resource.locale.name ,  default: "%{lang}:无可用博客模版") }
                    redirect_back({ fallback_location: ActiveAdmin.application.root_to }.merge(options)) 
                end 
            else
                options = { alert: I18n.t('active_admin.processing',  default: "安装正在受理,请耐心等待") }
                redirect_back({ fallback_location: ActiveAdmin.application.root_to }.merge(options))  
            end
        end

        member_action :update_wp_config, method: :put do   
             if resource.update_wp_config
                options = { notice: I18n.t('active_admin.notice.updated',  default: "Updated!") }
             else
                options = { alert: I18n.t('active_admin.notice.failure',  default: "更新失败") }
             end
             redirect_back({ fallback_location: ActiveAdmin.application.root_to }.merge(options))  
        end

        member_action :do_install, method: :put do   
             if params[:template_id]
                if resource.pending?
                    template = Template.find params[:template_id]
                    resource.install_with_template(template)
                    options = { notice: I18n.t('active_admin.installing',  default: "安装正在受理,10秒左右刷新页面，查看是否安装完成") }
                else
                    options = { alert: I18n.t('active_admin.processing',  default: "安装正在受理,请耐心等待") }
                end
                redirect_to  admin_blog_path(resource) , options 
             else
                options = { alert: I18n.t('active_admin.none_template', lang:  resource.locale.name ,  default: "%{lang}:无可用博客模版") }
                redirect_to admin_blog_path(resource) , options 
             end 
        end 
        # End member actions

        collection_action :migration, method: :get do 
            @blog = Blog.new
            # render template: 'admin/blogs/migration' 
        end

        collection_action :do_migration, method: :post do  
            options = { notice:  t('active_admin.updated', default: "Updated!") }
            redirect_to admin_blogs_path , options 
        end
  

        # Action items
        action_item :install, only: :show  do
            if resource.pending?
                link_to(
                    I18n.t('active_admin.install', default: "安装"),
                    install_admin_blog_path(resource),  
                    method: "put"
                  ) 
            end  
        end

        action_item :set_dns, only: :show  do
            unless resource.dns_status
                link_to(
                    I18n.t('active_admin.set_dns',  default: "设置DNS"),
                     set_dns_admin_blog_path(resource), 
                     method: "put"
                  ) 
            end  
        end

        action_item :login, only: :show  do
            if resource.can_login?
                link_to(
                    I18n.t('active_admin.login', default: "登陆"),
                    login_admin_blog_path(resource),  
                    method: "put"
                ) 
            end  
        end

        action_item :migration, only: :index  do 
            if current_admin_user.admin?
                link_to(
                    I18n.t('active_admin.migration', default: "网站迁移"),
                    action: :migration,
                    method: :get
                  )  
            end
        end

        action_item :update_wp_config, only: :show  do
            if resource.installed?
                link_to(
                    I18n.t('active_admin.update_wp_config', default: "更新配置"),
                    update_wp_config_admin_blog_path(resource),  
                    method: "put"
                  ) 
            end  
        end

        # End Action items

        csv do
            column :id
            column :number
            column :status
            column :name
            if current_admin_user.admin?
                column :user 
                column :password 
                column :mysql_user 
                column :mysql_password 
                column(:server)  { |source| source.server.host } 
            end  
            column(:locale)  { |source| source.locale.code } 
            column :origin
        end

        index do
            if Server.active.size.blank? 
                div class: "flash flash_error" do  
                    link_to "设置服务器", admin_servers_path
                end
            end
            if Cloudflare.active.size == 0 
                div class: "flash flash_error" do  
                    link_to "设置Cloudflare", admin_cloudflares_path
                end
            end
            selectable_column
            id_column    
            column :admin_user if authorized?(:read, AdminUser)
            column :number 
            column :locale do |source|
                source.locale.code
            end 
            column :server  if  authorized?(:read, Wordpress::Server)
            column :cloudflare if  authorized?(:read, Wordpress::Cloudflare) 
            
            column :website_url do |source|
                link_to  source.online_origin , source.online_origin, target: "_blank" if source.online_origin 
            end    
            column :reset_password do |source|
                link_to  I18n.t('active_admin.reset',  default: "Reset") , reset_password_admin_blog_path(source), method: :put  if source.can_login?   
            end  
            column :origin do |source|
                link_to image_tag("icons/interface.svg", width: "20", height: "20"), source.cloudflare_origin, target: "_blank" if source.can_login? 
            end  
            column :login do |source|
                link_to image_tag("icons/arrows.svg", width: "20", height: "20")  , login_admin_blog_path(source) , target: "_blank" , method: :put , class: "" if source.can_login?  
            end 
            column :name
            # column :description    
            tag_column :state, machine: :state   
            column :status    
            column :installed_at
            column :published_at 
            actions
        end

        filter :id  
        filter :number  
        filter :name  
        filter :description  
        filter :admin_user , if: proc { authorized?(:read, AdminUser) }
        filter :state, as: :check_boxes 
        filter :use_ssl , if: proc { authorized?(:read, Wordpress::Domain) }
        filter :server, if: proc { authorized?(:read, Wordpress::Server) }
        filter :cloudflare, if: proc { authorized?(:read, Wordpress::Cloudflare) }
        filter :domain_name, as: :string,  if: proc { authorized?(:read, Wordpress::Domain) }
        

        form do |f|
            f.inputs I18n.t("active_admin.blogs.form" , default: "Blog")  do  
                f.input :admin_user if authorized?(:update, AdminUser)
                f.input :locale if  current_admin_user.admin? || f.object.pending?
                # f.input :server_id , as: :select, collection: Wordpress::Server.all    
                # f.input :cloudflare_id , as: :select, collection: Wordpress::Cloudflare.all    
                if authorized?(:update, Wordpress::Domain)
                    f.input :domain_id,  as: :search_select, 
                                url:  admin_domains_path, 
                                fields: [:name], 
                                display_name: :name, 
                                minimum_input_length: 2     
                    f.input :cname, hint: "Demo: www"
                    f.input :use_ssl    
                end 
                f.input :name     
                f.input :description    
            end
            f.actions
        end  

        show do
            panel t('active_admin.details', model: resource_class.to_s.titleize) do
                attributes_table_for resource do 
                    row :admin_user  
                    row :locale 
                    row :server  
                    row :cloudflare
                    row :domain    
                    row :origin do |source|
                        link_to source.cloudflare_origin, source.cloudflare_origin
                    end
                    row :website_url do |source|
                        link_to source.online_origin, source.online_origin, target: "_blank" if source.online_origin
                    end 
                    row :name
                    row :description
                    tag_row :state, machine: :state  
                    row :dns_status 
                    row :installed_at  
                    row :published_at  
                    row :updated_at 
                    row :created_at   
                end
            end
            if resource.cloudflare?
                panel "Cloudflare CNAME Setup" do
                    if  resource.origin
                        table_for resource do 
                            column :host_name do 
                                "#{resource.origin}" if resource.origin
                            end
                            column :cname do 
                                "#{resource.origin}.cdn.cloudflare.net" if resource.origin
                            end
                        end
                    end
                    if  resource.other_origin
                        table_for resource do 
                            column :host_name do 
                                "#{resource.other_origin}" if resource.other_origin
                            end
                            column :cname do 
                                "#{resource.other_origin}.cdn.cloudflare.net" if resource.other_origin
                            end
                        end 
                    end

                end
            end
            active_admin_comments
        end

        sidebar :tips do 
            h3 "操作指南"
            ol do
                li "安装/迁移博客"
                li "博客达到上线标准【标记完成】"
                li "【编辑博客】填写域名信息" 
                li "网址准备就绪【发布】"
                li "找到PHP代理节点IP，并解析; 如使用Cloudflare Partner找到CNAME记录解析" 
                li "网站正常访问"
            end 
        end
    end
end