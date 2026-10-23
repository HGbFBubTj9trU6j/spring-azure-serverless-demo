IF NOT EXISTS (SELECT 1 FROM dbo.fortunes)
BEGIN
INSERT INTO dbo.fortunes (message)
VALUES
    (N'When in doubt, check the logs.'),
    (N'There is always one more configuration.'),
    (N'Automate the boring things.' + CHAR(13) + CHAR(10) + N'Debug the interesting ones.'),
    (N'If you did it twice,' + CHAR(13) + CHAR(10) + N'consider writing a script.'),
    (N'Deployments should be boring.');
END;
