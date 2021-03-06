USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_RemovePoolBracket_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_RemovePoolBracket_XML]
    @poolKey VARCHAR(100),
    @guid VARCHAR(100),
    @bracketKey VARCHAR(100)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 03/03/2015
-- Description:	remove bracket from pool
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- bad pool key
    IF NOT EXISTS (SELECT 1
                     FROM dbo.UGC_Pool_Names
                    WHERE pool_key = @poolKey)
    BEGIN
        SELECT 'invalid pool' AS [message], '400' AS [status], 'Invalid Pool' AS display
           FOR XML PATH(''), ROOT('root')
               
        RETURN
    END


    -- bad bracket key
    IF (@bracketKey <> '')
    BEGIN
        IF NOT EXISTS (SELECT 1
                         FROM dbo.UGC_Bracket_Names
                        WHERE [guid] = @guid AND bracket_key = @bracketKey)
        BEGIN
            SELECT 'invalid bracket' AS [message], '400' AS [status], 'Invalid Bracket' AS display
               FOR XML PATH(''), ROOT('root')
               
            RETURN
        END
    END


    -- exists
    IF EXISTS (SELECT 1
                 FROM dbo.UGC_Pools
                WHERE pool_key = @poolKey AND [guid] = @guid AND bracket_key = @bracketKey)
    BEGIN
        DECLARE @participants INT

        DELETE dbo.UGC_Pools
         WHERE pool_key = @poolKey AND [guid] = @guid AND bracket_key = @bracketKey

        SELECT @participants = COUNT(*)
          FROM dbo.UGC_Pools
         WHERE pool_key = @poolKey

        UPDATE dbo.UGC_Pool_Names
           SET participants = @participants
         WHERE pool_key = @poolKey
    END

    SELECT 'bracket removed from pool' AS [message], '200' AS [status]
       FOR XML PATH(''), ROOT('root')

	    
    SET NOCOUNT OFF;
END




GO
