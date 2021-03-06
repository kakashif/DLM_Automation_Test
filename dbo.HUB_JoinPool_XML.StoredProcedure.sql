USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_JoinPool_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_JoinPool_XML]
    @poolKey VARCHAR(100),
    @guid VARCHAR(100),
    @bracketKey VARCHAR(100),
    @center VARCHAR(100)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 02/18/2015
-- Description:	join pool
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @name VARCHAR(100)

    SELECT @name = name
      FROM dbo.UGC_Pool_Names
     WHERE pool_key = @poolKey

    -- bad pool key
    IF (@name IS NULL)
    BEGIN
        SELECT 'invalid pool' AS [message], '400' AS [status], 'Invalid Pool' AS display
           FOR XML PATH(''), ROOT('root')
               
        RETURN
    END


    -- bad guid
    IF NOT EXISTS (SELECT 1
                     FROM dbo.UGC_GUID_Names
                    WHERE [guid] = @guid)
    BEGIN
        SELECT 'invalid guid' AS [message], '400' AS [status], 'Invalid GUID' AS display
           FOR XML PATH(''), ROOT('root')
               
        RETURN
    END


    IF (@bracketKey <> '')
    BEGIN
        -- bad bracket key
        IF NOT EXISTS (SELECT 1
                         FROM dbo.UGC_Bracket_Names
                        WHERE [guid] = @guid AND bracket_key = @bracketKey)
        BEGIN
            SELECT 'invalid bracket' AS [message], '400' AS [status], 'Invalid Bracket' AS display
               FOR XML PATH(''), ROOT('root')
               
            RETURN
        END
    END


    -- already join
    IF EXISTS (SELECT 1
                 FROM dbo.UGC_Pools
                WHERE pool_key = @poolKey AND [guid] = @guid AND bracket_key = @bracketKey) 
    BEGIN
        SELECT 'already joined' AS [message], '400' AS [status], 'Already Joined' AS display, @bracketKey AS bracket_key
           FOR XML PATH(''), ROOT('root')
               
        RETURN
    END


    -- replace if empty bracket key exists
    IF EXISTS (SELECT 1
                 FROM dbo.UGC_Pools
                WHERE pool_key = @poolKey AND [guid] = @guid AND bracket_key = '')
    BEGIN
        UPDATE dbo.UGC_Pools
           SET bracket_key = @bracketKey
         WHERE pool_key = @poolKey AND [guid] = @guid AND bracket_key = ''
         
        SELECT 'pool bracket updated' AS [message], '200' AS [status], 'Updated pool bracket' AS display, @name AS name
           FOR XML PATH(''), ROOT('root')
               
        RETURN
    END


    DECLARE @participants INT

    INSERT INTO dbo.UGC_Pools (pool_key, [guid], bracket_key, date_time, center) 
    VALUES (@poolKey, @guid, @bracketKey, GETDATE(), @center)

    SELECT @participants = COUNT(*)
      FROM SportsDB.dbo.UGC_Pools
     WHERE pool_key = @poolKey

    UPDATE SportsDB.dbo.UGC_Pool_Names
       SET participants = @participants
     WHERE pool_key = @poolKey
         
    SELECT 'success' AS [message], '200' AS [status], 'Joined pool' AS display, @name AS name
       FOR XML PATH(''), ROOT('root')
    
    SET NOCOUNT OFF;
END




GO
