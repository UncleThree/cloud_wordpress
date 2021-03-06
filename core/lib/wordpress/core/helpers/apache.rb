module Wordpress
    module Core
        module Helpers
            class Apache
                attr_reader :ssh_info, :virtual

                def initialize( virtual )
                    @virtual = virtual
                end   

                def create_virtual_host(wordpress = '/wordpress/', server_alias = nil)
                    vhost_file = "/etc/httpd/conf.d/vhost/#{conf_file_name}"
                    ssh = "
                        mkdir /etc/httpd/conf.d/vhost -p 
                        echo \"#{virtual_host(wordpress)}\" > #{vhost_file}
                        service httpd restart 
                        echo 'Restart OK'
                        "
                end 

                def mkdir_directory
                    "mkdir #{virtual[:directory]} -p" 
                end

                def download_and_install(options) 
                    wordpress_config = "wordpress/wp-config.php"
                    " 
                    #{mkdir_directory}
                    if [ ! -f \"#{virtual[:directory]}/#{options[:template][:file_name]}\" ];then
                        cd #{virtual[:directory]} && wget #{virtual[:wordpress_down_url]} && tar xf #{options[:template][:file_name]} && chown apache:apache ./ -R 
                        sed -i \"s/#{ options[:template][:mysql_user]}/#{options[:blog][:mysql_user]}/g\" #{wordpress_config} 
                        sed -i \"s/#{ options[:template][:mysql_password]}/#{options[:blog][:mysql_password]}/g\" #{wordpress_config} 
                        sed -i \"s/#{ options[:template][:mysql_host] }/#{options[:blog][:mysql_host]}/g\" #{wordpress_config} 
                        sed -i \"/'WP_DEBUG'/a\\\if (\\\$_SERVER['HTTP_X_FORWARDED_HOST']) { \\\$scheme = 'http://'; if (\\\$_SERVER['HTTPS']=='on') { \\\$scheme = 'https://' ;} \\\$home = \\\$scheme.\\\$_SERVER['HTTP_X_FORWARDED_HOST']; \\\$siteurl = \\\$scheme.\\\$_SERVER['HTTP_X_FORWARDED_HOST']; define('WP_HOME', \\\$home); define('WP_SITEURL', \\\$siteurl); }\" #{wordpress_config}
                        sed -i \"/'WP_DEBUG'/a\\\if (\\\$_SERVER['HTTP_X_FORWARDED_PROTO']=='https') { \\\$_SERVER['HTTPS'] = 'on'; }\" #{wordpress_config}
                        sed -i \"s/#{options[:template][:id]}\\\/wordpress\\\///g\" #{virtual[:directory]}/wordpress/.htaccess
                    fi
                    "
                end

                private  

                
                def conf_file_name
                    "#{virtual[:server_name]}.conf" 
                end
 
                def virtual_host(wordpress, server_alias = nil)
                    server_alias = "ServerAlias #{server_alias}" unless server_alias.blank?
                    "
                    <VirtualHost *:#{virtual[:port]}>
                            ServerName #{virtual[:server_name]}
                            #{server_alias}
                            DocumentRoot #{virtual[:directory]}#{wordpress}
                            <Directory #{virtual[:directory]}#{wordpress}>
                                        Options All
                                        AllowOverride All
                                        Require all granted
                            </Directory>
                            <IfModule  mod_php5.c>
                                php_admin_value open_basedir #{virtual[:directory]}#{wordpress}:/tmp/
                            </IfModule>
                            <IfModule  mod_php7.c>
                                php_value open_basedir #{virtual[:directory]}#{wordpress}:/tmp/
                            </IfModule>
                    </VirtualHost> 
                    "
                end
            end
        end
    end
end