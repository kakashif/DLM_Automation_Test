USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetFiltersByStartDate_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetFiltersByStartDate_XML]
   @leagueKey VARCHAR(100),
   @page VARCHAR(100),
   @startDate DATETIME,   
   @filter	VARCHAR(100) = ''
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 05/01/2013
  -- Description: get filter by date
  -- Update: 06/04/2013 - John Lin - rename filter procedure
  --         06/05/2013 - John Lin - VARCHAR defaults to empty
  --         10/10/2013 - ikenticus: adding logic for solo sports
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    

	-- Solo Sports will start using league_name instead of league_key,
	-- but we have to utilize @leagueKey until we switch all leagues over
	IF @leagueKey IN (SELECT league_name FROM SMG_Solo_Leagues GROUP BY league_name)
	BEGIN
		DECLARE @leagueName VARCHAR(100) = @leagueKey
		-- Solo Sports will start using league_name instead of league_key,
		-- but we have to utilize @leagueKey until we switch all leagues over
		--EXEC dbo.SMG_GetScheduleResultFilters_XML @leagueName, @page, @seasonKey, @subLeagueName, @eventId
		EXEC dbo.SMG_GetScheduleResultFilters_XML @leagueName, @page, NULL, NULL, NULL
	END
	ELSE
	BEGIN
		EXEC dbo.SMG_GetScoreScheduleFilters_XML @leagueKey, @page, 0, '', '', @startDate, @filter
	END
       
END


GO
