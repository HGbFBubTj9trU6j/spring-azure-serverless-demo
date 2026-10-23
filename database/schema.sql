IF OBJECT_ID(N'dbo.fortunes', N'U') IS NULL
BEGIN
CREATE TABLE dbo.fortunes (
                              id BIGINT IDENTITY(1,1) NOT NULL,
                              message NVARCHAR(MAX) NOT NULL,

                              CONSTRAINT PK_fortunes PRIMARY KEY (id)
);
END;
