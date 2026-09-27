using './main.bicep'

param location = 'japaneast'

param resourceGroupName = 'spring-azure-serverless-demo-rg'

param containerRegistryName ='springazureserverlessdemoacr'

param containerAppsEnvironmentName = 'spring-azure-serverless-demo-dev-cae'

param identityName = 'spring-azure-serverless-demo-dev-id'

param containerAppName = 'spring-azure-serverless-dev-ca'

param containerImage = 'backend:0.0.1-SNAPSHOT'