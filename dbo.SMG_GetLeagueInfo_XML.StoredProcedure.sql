USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetLeagueInfo_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetLeagueInfo_XML]
    @leagueName VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 11/22/2013
  -- Description: get league info of league
  -- Update: 06/17/2014 - John Lin - use league name for SMG_Default_Dates
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @season_key INT
    
    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'

    EXEC dbo.SMG_GetLeagueInfoByYear_XML @leagueName, @season_key    	

    SET NOCOUNT OFF
END 

GO
