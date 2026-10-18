using './main.bicep'

param location = 'japaneast'

param resourceGroupName = 'spring-azure-serverless-demo-rg'

param containerRegistryName ='springazureserverlessdemodevacr'

param containerAppsEnvironmentName = 'spring-azure-serverless-demo-dev-cae'

param identityName = 'spring-azure-serverless-demo-dev-id'

param staticWebAppName = 'spring-azure-serverless-demo-dev-swa'

param staticWebAppLocation = 'eastasia'

param staticWebAppSku = 'Standard'
