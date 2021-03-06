USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_ReplacePoolBracket_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_ReplacePoolBracket_XML]
    @poolKey VARCHAR(100),
    @guid VARCHAR(100),
    @oldBracketKey VARCHAR(100),
    @newBracketKey VARCHAR(100)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 03/02/2015
-- Description:	replace bracket key
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @pool_name VARCHAR(100)

    SELECT @pool_name = name
      FROM dbo.UGC_Pool_Names
     WHERE pool_key = @poolKey

    -- bad pool key
    IF (@pool_name IS NULL)
    BEGIN
        SELECT 'invalid pool' AS [message], '400' AS [status], 'Invalid Pool' AS display
           FOR XML PATH(''), ROOT('root')
               
        RETURN
    END


    -- bad bracket key
    IF (@oldBracketKey <> '')
    BEGIN
        IF NOT EXISTS (SELECT 1
                         FROM dbo.UGC_Bracket_Names
                        WHERE [guid] = @guid AND bracket_key = @oldBracketKey)
        BEGIN
            SELECT 'invalid bracket' AS [message], '400' AS [status], 'Invalid Bracket' AS display
               FOR XML PATH(''), ROOT('root')
               
            RETURN
        END
    END

    -- bad bracket key
    DECLARE @bracket_name VARCHAR(100)

    IF (@newBracketKey <> '')
    BEGIN
        SELECT @bracket_name = name
          FROM dbo.UGC_Bracket_Names
         WHERE [guid] = @guid AND bracket_key = @newBracketKey

        IF (@bracket_name IS NULL)
        BEGIN
            SELECT 'invalid bracket' AS [message], '400' AS [status], 'Invalid Bracket' AS display
               FOR XML PATH(''), ROOT('root')
               
            RETURN
        END
    END

    -- already joined
    IF EXISTS (SELECT 1
                 FROM dbo.UGC_Pools
                WHERE pool_key = @poolKey AND [guid] = @guid AND bracket_key = @newBracketKey)
    BEGIN
        SELECT 'already joined' AS [message], '400' AS [status], 'Already Joined' AS display, @newBracketKey AS bracket_key
           FOR XML PATH(''), ROOT('root')
               
        RETURN
    END


    
    DELETE dbo.UGC_Pools
     WHERE pool_key = @poolKey AND [guid] = @guid AND bracket_key = @oldBracketKey

    INSERT INTO dbo.UGC_Pools (pool_key, [guid], bracket_key, date_time) 
    VALUES (@poolKey, @guid, @newBracketKey, GETDATE())


    SELECT 'replace success' AS [message], '200' AS [status], 'Replaced Pool Entry' AS display, @newBracketKey AS bracket_key,
           @pool_name AS pool_name, ISNULL(@bracket_name, '') AS bracket_name
       FOR XML PATH(''), ROOT('root')

	    
    SET NOCOUNT OFF;
END




GO
