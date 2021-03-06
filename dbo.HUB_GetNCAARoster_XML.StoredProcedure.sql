USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAARoster_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNCAARoster_XML]
    @teamSlug VARCHAR(100),
    @sport VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 03/26/2015
  -- Description: get default year roster for ncaa team
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @season_key INT
    DECLARE @league_key VARCHAR(100) = 'l.ncaa.org.mfoot'

	IF (@sport = 'mens-basketball')
	BEGIN
        SET @league_key = 'l.ncaa.org.mbasket'
	END
	ELSE IF (@sport = 'womens-basketball')
	BEGIN
        SET @league_key = 'l.ncaa.org.wbasket'
	END
	
	SELECT TOP 1 @season_key = season_key
	  FROM dbo.SMG_Rosters
	 WHERE league_key = @league_key
	 ORDER BY season_key DESC

    EXEC dbo.HUB_GetNCAARosterBySeasonKey_XML @teamSlug, @sport, @season_key
		
    SET NOCOUNT OFF
END

GO
