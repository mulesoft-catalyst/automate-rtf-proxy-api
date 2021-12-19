#!/usr/bin/env bash

echo "Reading Property envProperties.properties file"
PROPERTY_FILE=envProperties.properties

clientId=$(cat $PROPERTY_FILE | grep -w "clientId" | cut -d'=' -f2)
clientSecret=$(cat $PROPERTY_FILE | grep -w "clientSecret" | cut -d'=' -f2)
orgId=$(cat $PROPERTY_FILE | grep -w "orgId" | cut -d'=' -f2)
targetEnvId=$(cat $PROPERTY_FILE | grep -w "targetEnvId" | cut -d'=' -f2)
targetRTFClusterName=$(cat $PROPERTY_FILE | grep -w "targetRTFClusterName" | cut -d'=' -f2)
targetEnvName=$(cat $PROPERTY_FILE | grep -w "targetEnvName" | cut -d'=' -f2)
targetHostName=$(cat $PROPERTY_FILE | grep -w "targetHostName" | cut -d'=' -f2)
apiUri=$(cat $PROPERTY_FILE | grep -w "apiUri" | cut -d'=' -f2)
publicUrl=$(cat $PROPERTY_FILE | grep -w "publicUrl" | cut -d'=' -f2)
apiName=$(cat $PROPERTY_FILE | grep -w "apiName" | cut -d'=' -f2)
rtfAppName=$(cat $PROPERTY_FILE | grep -w "rtfAppName" | cut -d'=' -f2)

echo "Successfully mapped value to keys from properties file"

### Retrieve Access token using Connected APP ClientId and ClientSecret
### Pre-requisite - Create a connected app in Anypoint platform access management which has all required permissions

echo "Retrieving Access Token"

access_token=$(curl -s -X POST \
https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "client_id=$clientId&client_secret=$clientSecret&grant_type=client_credentials" | jq -r '.access_token')



if [ -z "$access_token" ];then
   echo "Failed in retrieving access_token. Please Check Client Id and Client Secret"
   exit 1   
fi

# echo "Successfully Retrieved Access Token :: $access_token"

### Checking if asset exists in exchange
echo "Checking if asset exists in exchange"
exchangeResponse=$(curl -s -X GET \
 "https://anypoint.mulesoft.com/apimanager/xapi/v1/organizations/$orgId/exchangeAssets?assetId=$apiName&groupId=$orgId" \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" -o exchangeResponse_${apiName}.json -w "%{http_code}")	

if [ $exchangeResponse != 200 ]
then
	echo "Failed during retrieving Exchange Asset, Please refer exchangeResponse_${apiName}.json for more information"
	exit 2
fi

groupId=$(jq -r '.apiDefinitions[0].groupId' exchangeResponse_${apiName}.json)
assetId=$(jq -r '.apiDefinitions[0].assetId' exchangeResponse_${apiName}.json)
version=$(jq -r '.apiDefinitions[0].version' exchangeResponse_${apiName}.json)

# echo "Successfully retrieved Exchange Asset - groupId :: $groupId, assetId :: $assetId, version :: $version "

### Retrieve latest proxy template 
echo "Retrieving latest proxy template"
proxyTemplateResponse=$(curl -s -X GET \
 "https://anypoint.mulesoft.com/apimanager/xapi/proxies/v1/proxy-templates?type=rest" \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" -o proxyTemplateResponse_${apiName}.json -w "%{http_code}")	

if [ $proxyTemplateResponse != 200 ]
then
	echo "Failed during retrieving proxy template, Please refer proxyTemplateResponse_${apiName}.json for more information"
	exit 3
fi

proxyTemplateVersion=$(jq -r '.data[0].assetVersion' proxyTemplateResponse_${apiName}.json)

#echo "Successfully retrieved latest proxy template :: $proxyTemplateVersion"

### Create API Request for proxy
echo "Create API Request for proxy"
$(jq --arg proxyTemplateVersion "${proxyTemplateVersion}" \
    --arg apiUri "${apiUri}" \
    --arg assetId "${assetId}" \
    --arg groupId "${groupId}" \
    --arg version "${version}" \
    '.endpoint.proxyTemplate.assetVersion = $proxyTemplateVersion | .endpoint.uri = $apiUri | .spec.assetId = $assetId | 
	 .spec.groupId = $groupId | .spec.version = $version' apiRequest.template.json > apiRequest_${apiName}.json )

echo "Successfuly created API request file"

### Retrieve target RTF detail
echo "Retrieve target RTF detail"

rtfDetailsResponse=$(curl -s -X GET \
 "https://anypoint.mulesoft.com/proxies/xapi/v1/organizations/$orgId/providers/MC/runtime-fabric-deployment-targets?environmentId=$targetEnvId" \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" -o rtfDetailsResponse_${apiName}.json -w "%{http_code}")	

if [ $rtfDetailsResponse != 200 ]
then
	echo "Failed during retrieving RTF details, Please refer rtfDetailsResponse_${apiName}.json for more information"
	exit 4
fi

targetRTF=$(cat rtfDetailsResponse_${apiName}.json | jq -c --arg targetRTFClusterName "$targetRTFClusterName" '.[] | select(.name | contains($targetRTFClusterName))')
targetId=$(echo $targetRTF | jq -r '.id')
runtimeVersion=$(echo $targetRTF | jq -c '.runtimes[] | select(.type | contains("mule"))' | jq -r '.versions[0].baseVersion')

#echo "Successfully retrieved RTF details for $targetRTFClusterName :: $targetId, runtimeVersion :: $runtimeVersion"

$(jq --arg RTFapiName "$rtfAppName" \
    --arg targetId "${targetId}" \
    --arg runtimeVersion "${runtimeVersion}" \
    '.name = $RTFapiName | .target.targetId = $targetId | .target.deploymentSettings.runtimeVersion = $runtimeVersion' rtfAppRequest.template.json > rtfAppRequest_${apiName}.json )

echo "Successfuly created RTF APP request file"

### Create API in API Manager
echo "Creating API in API Manager"

apiResponse=$(curl -s -X POST \
 "https://anypoint.mulesoft.com/apimanager/api/v1/organizations/$orgId/environments/$targetEnvId/apis" \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" \
 -d @apiRequest_${apiName}.json -o apiResponse_${apiName}.json -w "%{http_code}")	

if [ $apiResponse != 201 ]
then
	echo "Failed during Creating API in API Manager, Please refer apiResponse_${apiName}.json for more information"
	exit 5
fi

apiId=$(jq -r '.id' apiResponse_${apiName}.json)

echo "Successfully created API in API Manager with id :: $apiId"

### Create Proxy application in RTF
echo "Creating Proxy application in RTF"

rtfAppResponse=$(curl -s -X POST \
 "https://anypoint.mulesoft.com/proxies/xapi/v1/organizations/$orgId/environments/$targetEnvId/apis/$apiId/deployments" \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" \
 -d @rtfAppRequest_${apiName}.json -o rtfAppResponse_${apiName}.json -w "%{http_code}")

if [ $rtfAppResponse != 201 ]
then
	echo "Failed during Creating APP in Runtime Fabric, Please refer rtfAppResponse_${apiName}.json for more information"
	exit 6
fi

rtfDeploymentId=$(jq -r '.id' rtfAppResponse_${apiName}.json)

#echo "Successfully started deployment in RTF with id :: $rtfDeploymentId , waiting for deployment to be completed"

sleep 360

deployStatusResponse=$(curl -s -X GET \
 "https://anypoint.mulesoft.com/proxies/xapi/v1/organizations/$orgId/environments/$targetEnvId/apis/$apiId/deployments/$rtfDeploymentId/status" \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" -o deployStatusResponse_${apiName}.json -w "%{http_code}")	

if [ $deployStatusResponse != 200 ]
then
	echo "Failed during retrieving deployment status, Please refer deployStatusResponse_${apiName}.json for more information"
	exit 7
fi

deployStatus=$(jq -r '.status' deployStatusResponse_${apiName}.json)

#echo "deployStatus: $deployStatus"

if [ $deployStatus = 'started' ]
then
	echo "Proxy APP successfully deployed"
fi

### Retrieving the Deployment Id"
echo "Retrieving the Deployment Id"
rtfDeploymentsResponse=$(curl -s -X GET \
	https://anypoint.mulesoft.com/hybrid/api/v2/organizations/$orgId/environments/$targetEnvId/deployments \
	-H "Authorization: Bearer $access_token" \
	-H "Content-Type: application/json" -o rtfDeploymentsResponse_${apiName}.json -w "%{http_code}")		

if [ $rtfDeploymentsResponse != 200 ]
then
	echo "Failed during retrieving Deployment information, Please refer rtfDeploymentsResponse_${apiName}.json for more information"
	exit 8
fi

rtfDeploymentId=$(jq -c --arg appName "$rtfAppName" '.items[] | select(.name | contains($appName))' rtfDeploymentsResponse_${apiName}.json | jq -r '.id')

if [ -z "$rtfDeploymentId" ];then
	echo "Deployment Id not found in Source Environment for $rtfAppName. Please refer rtfDeploymentsResponse_${apiName}.json for more information"
	exit 9
fi

#echo "RTF Deployment Id :: $rtfDeploymentId"

### Retrieve deployment details for RTF App"
echo "Retrieving the Deployment details"
rtfDeploymentDetailsResponse=$(curl -s -X GET \
	https://anypoint.mulesoft.com/hybrid/api/v2/organizations/$orgId/environments/$targetEnvId/deployments/$rtfDeploymentId \
	-H "Authorization: Bearer $access_token" \
	-H "Content-Type: application/json" -o rtfDeploymentDetailsResponse_${apiName}.json -w "%{http_code}")	

if [ $rtfDeploymentDetailsResponse != 200 ]
then
	echo "Failed during retrieving deployment details information, Please refer rtfDeploymentDetailsResponse_${apiName}.json for more information"
	exit 10
fi

groupId=$(jq -r '.application.ref.groupId' rtfDeploymentDetailsResponse_${apiName}.json)
artifactId=$(jq -r '.application.ref.artifactId' rtfDeploymentDetailsResponse_${apiName}.json)
version=$(jq -r '.application.ref.version' rtfDeploymentDetailsResponse_${apiName}.json)

# echo "Successfully retrieved RTF deployment Asset details- groupId :: $groupId, artifactId :: $artifactId, version :: $version"

### Create API Request for proxy
echo "Create request for patching RTF APP"
$(jq --arg publicUrl "${publicUrl}" \
    --arg groupId "${groupId}" \
    --arg artifactId "${artifactId}" \
    --arg version "${version}" \
    '.target.deploymentSettings.http.inbound.publicUrl = $publicUrl | .application.ref.groupId = $groupId | .application.ref.artifactId = $artifactId | 
	 .application.ref.version = $version' patchPublicUrl.template.json > patchPublicUrl_${apiName}.json )

echo "Successfuly created patch RTF APP request file"

### Update deployment details for RTF APP"
echo "Updating the RTF APP Public URL"
patchRTFAppResponse=$(curl -s -X PATCH \
	https://anypoint.mulesoft.com/hybrid/api/v2/organizations/$orgId/environments/$targetEnvId/deployments/$rtfDeploymentId \
	-H "Authorization: Bearer $access_token" \
	-H "Content-Type: application/json" \
	-d @patchPublicUrl_${apiName}.json -o patchRTFAppResponse_${apiName}.json -w "%{http_code}")

if [ $patchRTFAppResponse != 200 ]
then
	echo "Failed during patching RTF application, Please refer patchRTFAppResponse_${apiName}.json for more information"
	exit 11
fi

sleep 360 

### Check deployment status. If it is not successful go through error workflow like delete application from exchange, send notification etc.

deployStatusResponse=$(curl -s -X GET \
 https://anypoint.mulesoft.com/hybrid/api/v2/organizations/$orgId/environments/$targetEnvId/deployments/$rtfDeploymentId \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" -o deployStatusResponse_${apiName}.json -w "%{http_code}")

if [ $deployStatusResponse != 200 ]
then
	echo "Failed to retrieve RTF application deployment status, Please refer deployStatusResponse_${apiName}.json for more information"
	exit 12
fi

deployStatus=$(jq -r '.status' deployStatusResponse_${apiName}.json)
appStatus=$(jq -r '.application.status' deployStatusResponse_${apiName}.json)

#echo "deployStatus: $deployStatus,appStatus: $appStatus"

if [ $deployStatus = 'APPLIED' ] && [ $appStatus = 'RUNNING' ] 
then
	echo "Asset successfully updated"
fi

rm -rf *_$apiName.json

echo "All temporary files successfully deleted"
