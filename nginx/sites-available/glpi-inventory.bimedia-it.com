# Servers
server {
	listen 80 ;
	listen [::]:80 ;
		
		if ($http_x_forwarded_proto = "http") {
            return 301 https://$host$request_uri;
    }
    
	server_name glpi-inventory.mondomaine.org  ;
	server_tokens off;
	index index.php index.html index.htm;
	root /var/www/html/glpi-v10/public;
	gzip on;
	gzip_vary on;
	gzip_comp_level 6;
	gzip_types text/plain text/css application/json application/x-javascript application/javascript text/xml application/xml application/rss+xml text/javascript image/svg+xml application/vnd.ms-fontobject application/x-font-ttf font/opentype;
	gzip_proxied    no-cache no-store private expired auth;
	#gzip_min_length 1000;
	error_log /var/log/nginx/glpi-inventory.mondomaine.org.error.log;
	access_log /var/log/nginx/glpi-inventory.mondomaine.org.access.log;
	

	include	snippets/nginx-status.conf;
	include	snippets/nginx-robots.conf;
	include	snippets/fpm-status.conf;
	
	location ~ [^/]\.php(/|$) {
	fastcgi_split_path_info ^(.+\.php)(/.+)$;
	# NOTE: You should have "cgi.fix_pathinfo = 0;" in php.ini
	fastcgi_pass unix:/var/run/php/php8.3-fpm--www-glpi-front.sock;
	fastcgi_index index.php;
	include snippets/fastcgi_params;
	fastcgi_param HTTPS on;
	fastcgi_buffers 16 16k;
	fastcgi_buffer_size 32k;
	client_max_body_size 32M;
	}

	location ~* \.(?:jpg|jpeg|gif|png|PNG|ico|cur|gz|svg|mp4|ogg|ogv|webm|htc)$ {
		access_log off;
		add_header Cache-Control "max-age=2592000";
	}

	location ~* \.svgz$ {
		access_log off;
		gzip off;
		add_header Cache-Control "max-age=2592000";
	}

	location /files {
		deny all;
	}

#
# Deny access to .htaccess files, if Apache's document root concurs with nginx's one
#
	location ~ /\.ht {
		deny all;
	}
#
# on suprime l'accès a /
#
	location = / {
		deny all;
	}
#
# on suprime l'accès a tout
#
	location ~^/[^/]+$ {
		deny all;
	}
#
# on  limite le nb de connexion sur fusioninventory
#
	location ^~ /plugins/fusioninventory/.* {
		allow all;
		limit_req zone=fusioninventory burst=10 nodelay;
		limit_conn addr 4;
	}
#
# on  limite le nb de connexion sur fusioninventory
#
	location ^~ /plugins/glpiinventory/.* {
		allow all;
		limit_req zone=fusioninventory burst=10 nodelay;
		limit_conn addr 4;
	}
	location /repository {
		alias /var/lib/glpi/_plugins/glpiinventory/files/repository;
	}
#
# pas de /tickets ici
# on log les ips qui tapent pas au bon endroit
#
	location ^~ /glpi-front-v10/ {
		deny all;
		access_log /var/log/nginx/glpi-inventory-wrong-path.log;
	}

}
