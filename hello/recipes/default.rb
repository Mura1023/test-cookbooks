### AWS OpsWorks Handson CLI text
## Install git on Git client and make recipe
sudo yum update
sudo yum install git
mkdir -p ~/site-cookbooks/hello/recipes
vi ~/site-cookbooks/hello/recipes/default.rb

------------ default.rb start-------------------
file "/home/ec2-user/hello.txt" do
  action :create
end
------------ default.rb-------------------------------


## Git setup and push default.rb into GitHub
cd ~/site-cookbooks
git init
git add .
git commit -m "first commit"
git remote add origin https://github.com/xxxxxx/test-cookbooks.git 
git push -u origin master


## SSH login into PHP App Server instance
ls /home/ec2-user

## Stack custom json
----------- custom json start--------------
{
 "deploy": {
   "wordpress": {
      "wp_admin_email" : "xxxxxx@hlc.co.jp" 
   } 
 }
}
----------- custom json end--------------

## Check Stack JSON
sudo su
opsworks-agent-cli get_json

## Create Chef recipes for Wordpress setup
cd ~/site-cookbooks
mkdir -p wp-cli/recipes
vi wp-cli/recipes/default.rb

------------ default.rb start-------------------
wpdir = "/usr/bin/"

remote_file "#{wpdir}/wp" do
  source "https://download-for-aws-training2.s3-ap-northeast-1.amazonaws.com/wp-cli-1.5.1.phar"
  owner "root"
  group "root"
  mode 00755
  checksum "0cc7a95e68a2ef02fc423614806c29a8e76e4ac8c9b3e67d6673635d6eaea871"
end
------------ default.rb end-------------------

vi wp-cli/recipes/deploy.rb

------------ deploy.rb start------------------
require "net/http"
require "uri"

wpdir = "/srv/www/wordpress/current"
dbname = node[:deploy][:wordpress][:database][:database]
dbuser = node[:deploy][:wordpress][:database][:username]
dbpass = node[:deploy][:wordpress][:database][:password]
dbhost = node[:deploy][:wordpress][:database][:host]
wp_admin_email = node[:deploy][:wordpress][:wp_admin_email]

execute "wp configure" do
   command "wp core config --dbname=#{dbname} --dbuser=#{dbuser} --dbpass=#{dbpass} --dbhost=#{dbhost}"
   cwd "#{wpdir}"
   user "deploy"
   not_if { File.exists?("#{wpdir}/wp-config.php") }
   action :run
end


uri = URI.parse("http://169.254.169.254/latest/meta-data/public-hostname")
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Get.new(uri.request_uri)
response = http.request(request)

public_hostname = response.body

execute "db create" do
   command "wp db create"
   cwd "#{wpdir}"
   user "deploy"
   action :run
   ignore_failure true
end

execute "wp deploy" do
   command "wp core install --url=#{public_hostname} --title=Test --admin_name=admin --admin_password=admin --admin_email=#{wp_admin_email}"
   cwd "#{wpdir}"
   user "deploy"
   action :run
   not_if "sudo -u deploy wp core is-installed --path=#{wpdir}"
end
------------ deploy.rb end--------------------

## git commit and push recipes to GitHub
cd ~/site-cookbooks
git add .
git commit -m "create wp-cli recipe"
git push origin master


## Check Stack JSON
sudo su
opsworks-agent-cli get_json



### Appendix
## OpsWorksインスタンス上でCLIでレシピをアップデートして実行する
sudo opsworks-agent-cli run_command update_custom_cookbooks
sudo opsworks-agent-cli run_command execute_recipes hello
