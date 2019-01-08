#!/usr/bin/env bash

sonar_url="http://localhost:9000"
sonar_api_user=admin
sonar_api_password=admin

sonar_plugins="ansible authgithub yaml"

# wait for sonar to come up
system_health=$(curl -s -u $sonar_api_user:$sonar_api_password $sonar_url/api/system/health | jq -r .health)
while [ "$system_health" != "GREEN" ];do
    echo "Sonarqube status is $system_health...Waiting"
    sleep 5
    system_health=$(curl -s -u $sonar_api_user:$sonar_api_password $sonar_url/api/system/health | jq -r .health)
done

echo "Sonarqube is UP, starting initial configuration..."

# install required plugins
echo "Installing plugins..."
for plugin in $sonar_plugins; do
    echo "Plugin '$plugin' is being installed.."
    curl -s -XPOST -u $sonar_api_user:$sonar_api_password $sonar_url/api/plugins/install -d "key=$plugin"
done

# generate admin token
echo "Generation of admin token..."
sonar_admin_token="$(curl -s -XPOST -u $sonar_api_user:$sonar_api_password $sonar_url/api/user_tokens/generate -d "name=admin integration token" | jq -r .token)"

echo "Integration token is '$sonar_admin_token'. Please note it down!"

# check if restart is needed
plugin_status=$(curl -s -u $sonar_api_user:$sonar_api_password $sonar_url/api/plugins/pending | jq -r .installing)
echo "Plugins status is: '$plugin_status'"

if [ "$plugin_status" != "[]" ];then
        echo "Restarting Sonarqube..."
        curl -s -XPOST -u $sonar_api_user:$sonar_api_password $sonar_url/api/system/restart
    else
        echo "Skipping system restart..."
fi

# wait for sonar to come up
system_health=$(curl -s -u $sonar_api_user:$sonar_api_password $sonar_url/api/system/health | jq -r .health)
while [ "$system_health" != "GREEN" ];do
    echo "Sonarqube status is $system_health...Waiting"
    sleep 5
    system_health=$(curl -s -u $sonar_api_user:$sonar_api_password $sonar_url/api/system/health | jq -r .health)
done

echo "Sonarqube is UP, proceeding with further configuration..."

# enable all rules for YAML quality profile
# first we need to identify quality profile key
default_profile_key="$(curl -s -XPOST -u admin:admin http://localhost:9000/api/qualityprofiles/search -d "language=yaml" -d "qualityProfile=Sonar way" | jq -r .profiles[0].key)"

# then we need to create our own profile in order to be able to bulk activate all rules
echo "Creating new YAML quality profile 'My way'..."
my_profile_key="$(curl -s -XPOST -u $sonar_api_user:$sonar_api_password $sonar_url/api/qualityprofiles/copy -d "fromKey=$default_profile_key" -d "toName=My way" | jq -r .key)"

# then we can activate all rules
echo "Enabling quality profiles rules for 'My way' profile..."
curl -s -XPOST -u $sonar_api_user:$sonar_api_password $sonar_url/api/qualityprofiles/activate_rules -d "targetKey=$my_profile_key" > /dev/null

# create new project
echo "Creating new project 'Ansible Lint Project'..."
curl -s -XPOST -u $sonar_api_user:$sonar_api_password $sonar_url/api/projects/create \
                -d "key=ansible_lint_project" \
                -d "name=Ansible Lint Project"

# associate a project with a quality profile.
echo "Associating project 'Ansible Lint Project' with 'My way' quality profile..."
curl -s -XPOST -u $sonar_api_user:$sonar_api_password $sonar_url/api/qualityprofiles/add_project \
                -d "language=yaml" \
                -d "project=ansible_lint_project" \
                -d "qualityProfile=My way"

# configure webhook
echo "Creating webhook..."
curl -s -XPOST -u $sonar_api_user:$sonar_api_password $sonar_url/api/webhooks/create \
                -d "name=Ansible Lint Project webhook" \
                -d "project=ansible_lint_project" \
                -d "url=http://jenkins/sonarqube-webhook/"

echo "Configuration done!"