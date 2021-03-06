USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetLeagues_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetLeagues_XML]
    @platform VARCHAR(100) = 'mobile'
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 01/02/2014
  -- Description: get available leagues for mobile
  -- Update: 05/19/2015 - John Lin - add platform
  --         07/15/2015 - John Lin - remove suppression
  -- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
    (
        SELECT sport AS leagues
          FROM dbo.SMG_Suspender_List
         WHERE [platform] = @platform AND active = 1
         ORDER BY [order] ASC
           FOR XML PATH(''), TYPE
    )
    FOR XML PATH(''), ROOT('root')
    
    SET NOCOUNT OFF;
END

GO
