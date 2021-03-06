USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_DeleteStandings]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_DeleteStandings]
    @leagueKey VARCHAR(100),
	@seasonKey INT,
	@dateTime VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 11/12/2014
-- Description:	Delete Standings by specific league_key + season_key + date_time
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DELETE FROM SportsEditDB.dbo.SMG_Standings
	 WHERE team_key LIKE @leagueKey + '-t.%' AND season_key = @seasonKey AND date_time = @dateTime

END


GO
