# Servers
server {
	listen 80 ;
	listen [::]:80 ;
		listen 443 ssl    ;
	listen [::]:443 ssl    ;
		
		if ($http_x_forwarded_proto = "http") {
            return 301 https://$host$request_uri;
    }
    
	server_name glpi-front-v10.mondomaine.org  glpi-front.mondomaine.org ;
	server_tokens off;
	index index.php index.html index.htm;
	root /var/www/html/glpi-v10/public;
	gzip on;
	gzip_vary on;
	gzip_comp_level 6;
	gzip_types text/plain text/css application/json application/x-javascript application/javascript text/xml application/xml application/rss+xml text/javascript image/svg+xml application/vnd.ms-fontobject application/x-font-ttf font/opentype;
	gzip_proxied    no-cache no-store private expired auth;
	#gzip_min_length 1000;
	error_log /var/log/nginx/glpi-front-v10.mondomaine.org.error.log;
	access_log /var/log/nginx/glpi-front-v10.mondomaine.org.access.log timed_combined;
	
	# ssl on;
	ssl_certificate /etc/ssl/mondomaine/mondomaine.org.withintermediate.crt;
	ssl_certificate_key /etc/ssl/mondomaine/mondomaine.org.key;
		
	include	snippets/nginx-status.conf;
	include	snippets/nginx-robots.conf;

	# Allow from our Public vrrp 
	allow 50.51.52.53/28;
	# Allow from our private-lan
	allow 10.0.0.0/16;
	#### Allow of our Ip public for specific use 
	allow 11.11.11.11;
	allow 12.12.12.12;
	deny  all;
	

	location / {
			try_files $uri /index.php$is_args$args;
		autoindex off;
	}

	location /api/ {
			rewrite ^/api/(.*)$ /apirest.php/$1 last;
		autoindex off;
		allow  all;
	}

	location ~ ^/apirest\.php$ {
		fastcgi_pass unix:/var/run/php/php8.3-fpm--www-glpi-front.sock;
		fastcgi_split_path_info ^(.+\.php)(/.+)$;
		try_files $fastcgi_script_name =404;
		fastcgi_read_timeout 1300;
		fastcgi_send_timeout 1300;
		fastcgi_connect_timeout 300;
		fastcgi_keep_conn on;
		proxy_read_timeout 1300;
		proxy_send_timeout 1300;
		fastcgi_param HTTPS on;
		fastcgi_buffers 16 64k;
		fastcgi_buffer_size 64k;
		set $path_info $fastcgi_path_info;
		fastcgi_param  PATH_INFO $path_info;
		fastcgi_param  PATH_TRANSLATED    $document_root$fastcgi_script_name;
		fastcgi_param  SCRIPT_FILENAME    $document_root$fastcgi_script_name;
		include snippets/fastcgi_params;
	}

	location ~ ^/index\.php$ {
			fastcgi_pass unix:/var/run/php/php8.3-fpm--www-glpi-front.sock;
		fastcgi_split_path_info ^(.+\.php)(/.+)$;
		try_files $fastcgi_script_name =404;
		fastcgi_read_timeout 1300;
		fastcgi_send_timeout 1300;
		fastcgi_connect_timeout 120;
	 	fastcgi_keep_conn on;
		proxy_read_timeout 1300;
		proxy_send_timeout 1300;
		fastcgi_param HTTPS on;
		fastcgi_buffers 16 64k;
		fastcgi_buffer_size 64k;
		set $path_info $fastcgi_path_info;
		fastcgi_param  PATH_INFO $path_info;
		fastcgi_param  PATH_TRANSLATED    $document_root$fastcgi_script_name;
		fastcgi_param  SCRIPT_FILENAME    $document_root$fastcgi_script_name;
		include snippets/fastcgi_params;	
	}
#
# Deny access to .htaccess files, if Apache's document root concurs with nginx's one
#
	location ~ /\.ht {
			deny all;
	}
#
# on  limite le nb de connexion sur fusioninventory
#
	location ^~ /plugins/fusioninventory/.* {
		allow all;
		limit_req zone=fusioninventory burst=10 nodelay;
		limit_conn addr  1;
		access_log /var/log/nginx/fusioninventory-wrong-host.log;
	}

	location /status.php$ {
			access_log off;
	}

}
