USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAAStatistics_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNCAAStatistics_XML]
    @teamSlug VARCHAR(100),
    @sport VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 11/20/2014
  -- Description: split statistics for ncaa into football and basketball
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@sport = 'football')
    BEGIN
        EXEC dbo.HUB_GetNCAAStatistics_football_XML @teamSlug
    END
    ELSE
    BEGIN
        EXEC dbo.HUB_GetNCAAStatistics_basketball_XML @teamSlug, @sport
    END

    SET NOCOUNT OFF
END

GO
