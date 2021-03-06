USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_getTeamInfo_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_getTeamInfo_XML]
    @leagueName VARCHAR(100),
    @teamSlug VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 08/01/2013
  -- Description: get team info of league
  -- Update: 11/22/2013 - John Lin - add team slug
  --         05/20/2014 - John Lin - use league name
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @season_key INT
         
    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'

    EXEC dbo.SMG_GetTeamInfoByYear_XML @leagueName, @teamSlug, @season_key

    SET NOCOUNT OFF
END 

GO
