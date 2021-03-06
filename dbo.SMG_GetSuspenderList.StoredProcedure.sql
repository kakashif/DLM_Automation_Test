USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetSuspenderList]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetSuspenderList]
    @full_list INT = 0,
    @platform VARCHAR(100) = 'desktop'
AS
-- =============================================
-- Author:		John Lin
-- Create date: 07/12/2013
-- Description:	Get suspender list
-- Update: 05/19/2015 - John Lin - add platform
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF (@full_list = 1)
    BEGIN
        SELECT
        (
            SELECT sport AS name, [order], active
              FROM dbo.SMG_Suspender_List
             WHERE [platform] = @platform
               FOR XML RAW('sports'), TYPE
        )
        FOR XML PATH(''), ROOT('edits')
    END
    ELSE
    BEGIN
        SELECT
        (
            SELECT sport AS name
              FROM dbo.SMG_Suspender_List
             WHERE [platform] = @platform AND active = 1
             ORDER BY [order] ASC
               FOR XML RAW('sports'), TYPE
        )
        FOR XML PATH(''), ROOT('edits')
    END
    
    SET NOCOUNT OFF;
END

GO
