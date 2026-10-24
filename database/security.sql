IF DATABASE_PRINCIPAL_ID(N'$(ManagedIdentityName)') IS NULL
BEGIN
    CREATE USER [$(ManagedIdentityName)]
FROM EXTERNAL PROVIDER;
END;

IF IS_ROLEMEMBER(
    N'db_datareader',
    N'$(ManagedIdentityName)'
) = 1
BEGIN
    ALTER ROLE db_datareader
    DROP MEMBER [$(ManagedIdentityName)];
END;

GRANT SELECT
ON OBJECT::dbo.fortunes
TO [$(ManagedIdentityName)];

GRANT INSERT
ON OBJECT::dbo.fortunes
TO [$(ManagedIdentityName)];

GRANT DELETE
ON OBJECT::dbo.fortunes
TO [$(ManagedIdentityName)];
