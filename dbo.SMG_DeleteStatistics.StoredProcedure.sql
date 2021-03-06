USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_DeleteStatistics]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_DeleteStatistics]  
    @leagueKey VARCHAR(100),
	@seasonKey INT,
	@subSeasonType VARCHAR(100),
	@teamKey VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 12/19/2014
-- Description:	Delete Statistics by specific league_key + season_key + sub_season_key + team_key
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DELETE FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @leagueKey AND team_key = @teamKey
	   AND season_key = @seasonKey AND sub_season_type = @subSeasonType

END


GO
