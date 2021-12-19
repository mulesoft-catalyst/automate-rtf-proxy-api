# Automate RTF Proxy APP deployment | Platform API | Shell script

# Introduction

Protect your APIs or web services against attacks by using API proxies, which function as intermediaries between the external applications and the backend server. The API proxy is agnostic to your backend’s location and programming language. Additionally, your backend can be a non-Mule application.

When you deploy an API proxy in front of your API, the proxy adopts API gateway capabilities to secure the API by using different types of policies. Anypoint Platform enables you to deploy the proxy application directly to CloudHub or Anypoint Runtime Fabric. Your proxy application is then automatically tracked by API Manager.

API Manager automatically generates the proxy application when you configure your API as an endpoint with a proxy and includes an autodiscovery feature in the application. Mule locks the API until all policies have been applied. The client application (consumer) calls the proxy, which then forwards the call to the API. After you deploy the application, the Mule instance calls API Manager using the client ID and secret to obtain the policies for the API.

Runtime Fabric allows you to host API Proxies. However, after introduction of ingress v2 for Self-Managed Kubernetes the publicUrl for API proxy should match the Ingress rule for mule application which is currently not handled correctly by API Manager proxy API.
The script shared tries to solve this problem by automating creation of API proxy and modifying PublicUrl for proxy API.

# Problem Statement
Current API proxy template in API Manager creates Public Endpoint for Ingress as below

![Alt text](/screenshots/Ingress-config-ootb.png?raw=true "Public Url from API Manager template")

Expected Public Endpoint by RTF Cluster Ingress


![Alt text](/screenshots/Ingress-config-expected.png?raw=true "Public Url from API Manager template")

# Prerequisites 

The script requires a few supporting files to be created and updated with details so it can automate deployment.

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
- apiName = Asset ID for Mule proxy API spec in exchange
- rtfAppName = Application name for RTF Mule proxy APP

Note - Make sure Connected APP has all necessary permissions to create API in API Manager and proxy APP in RTF cluster.

### apiRequest.template.json
This is a template file which allows you to create proxy api instance type in API Manager.

### rtfAppRequest.template.json
This is a template file which allows you to create mule proxy APP in RTF cluster.

### patchPublicUrl.template.json
This is a template file which allows you to update public endpoint for mule proxy APP in RTF cluster 

Note - The template file placeholders are updated by the the shell script 
