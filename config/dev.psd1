@{
    Location                     = "japaneast"

    ResourceGroup                = "spring-azure-serverless-demo-rg"

    AcrName                      = "springazureserverlessdemodevacr"

    ContainerAppsEnvironmentName = "spring-azure-serverless-demo-dev-cae"

    IdentityName                 = "spring-azure-serverless-demo-dev-id"
    GithubActionsIdentityName    = "spring-azure-serverless-demo-dev-github-id"
    ContainerAppName             = "spring-azure-serverless-dev-ca"

    StaticWebAppName             = "spring-azure-serverless-demo-dev-swa"

    StaticWebAppLocation         = "eastasia"

    StaticWebAppSku              = "Standard"

    # Azure SQL
    SqlServerName                = "spring-azure-serverless-demo-dev-sql"
    SqlDatabaseName              = "fortune"

    # Buildpacks
    # Pin the builder by digest for reproducible builds.
    BackendBuilderImage = "paketobuildpacks/builder-noble-java-tiny@sha256:96678722f0d61f6102ceccd83f829a935a304fc353bbd5b20bbbfd90c28533b8"

    # DevSecOps
    SecurityReportStorageAccountName = "springazureserverlesssec"
    SecurityReportContainerName      = "security-reports"
}
