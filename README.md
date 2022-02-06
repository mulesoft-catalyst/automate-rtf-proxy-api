# Automate RTF Proxy APP deployment | Platform API | Shell script

# Introduction

Protect your APIs or web services against attacks by using API proxies, which function as intermediaries between the external applications and the backend server. The API proxy is agnostic to your backend’s location and programming language. Additionally, your backend can be a non-Mule application.

When you deploy an API proxy in front of your API, the proxy adopts API gateway capabilities to secure the API by using different types of policies. Anypoint Platform enables you to deploy the proxy application directly to CloudHub or Anypoint Runtime Fabric. Your proxy application is then automatically tracked by API Manager.

API Manager automatically generates the proxy application when you configure your API as an endpoint with a proxy and includes an autodiscovery feature in the application. Mule locks the API until all policies have been applied. The client application (consumer) calls the proxy, which then forwards the call to the API. After you deploy the application, the Mule instance calls API Manager using the client ID and secret to obtain the policies for the API.

Runtime Fabric allows you to host API Proxies. However, after introduction of ingress v2 for Self-Managed Kubernetes you can have multiple ingress inside a single RTF cluster. The proxy created using API Manager does not allow you to choose the public URL for the proxy api. The API manager template also allocates pre-fixed value for CPU and Memory for proxy api which may be high or low based on your requirement for the proxy api.
The script shared tries to solve this problem by automating creation of API proxy, modifying PublicUrl for proxy API and allocating resource to porxy api in an automated manner.

# Problem Statement
- Current API proxy template in API Manager does not allow user to choose Public Endpoint for Ingress
- API manager template allocates pre-fixed value for CPU and Memory for proxy api

# Prerequisites 
1. Install jq from https://stedolan.github.io/jq/download/ 

2. The script requires a few supporting files to be created and updated with details so it can automate deployment.

### envProperties.properties
Update below values in the file - 

- clientId = ClientId of Connected APP
- clientSecret = ClientSecret of Connected APP
- orgId = Organization ID
- targetEnvId = Environment ID where proxy APP will be deployed
- targetRTFClusterName = RTF Cluster Name 
- targetEnvName = Environment name where proxy APP will be deployed
- targetHostName = Host name for Mule proxy APP 
- apiUri = Implementation Url for Mule proxy APP
- publicUrl = Public Endpoint for Mule proxy APP
- apiName = Asset ID for Mule proxy API spec in exchange or Asset ID for HTTP asset to be created in Exchange for HTTP Proxies
- apiVersion = Asset version of HTTP asset to be created in Exchange for HTTP Proxies
- rtfAppName = Application name for RTF Mule proxy APP
- cpuReserved = The amount of vCPU guaranteed to the application and reserved for its use.
- cpuMax = The maximum amount of vCPU the application can use (the level to which it can burst)
- memory = Memory to be allocated to Mule proxy app

Note - Make sure Connected APP has all necessary permissions to create API in API Manager and proxy APP in RTF cluster.

### apiRequest.template.json
This is a template file which allows you to create proxy api instance type in API Manager.

### rtfAppRequest.template.json
This is a template file which allows you to create mule proxy APP in RTF cluster.

### patchPublicUrl.template.json
This is a template file which allows you to update public endpoint for mule proxy APP in RTF cluster 

Note - The template file placeholders are updated by the the shell script 

# Run the script

To create HTTP Mule Proxy APP
```
$ sudo chmod 755 createHTTPMuleProxy.sh
$ ./createHTTPMuleProxy.sh
```

To create Mule Proxy APP from Exchange
```
$ sudo chmod 755 createMuleProxy.sh
$ ./createMuleProxy.sh
```


