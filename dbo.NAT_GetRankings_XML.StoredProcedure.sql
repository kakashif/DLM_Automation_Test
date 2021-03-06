USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[NAT_GetRankings_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[NAT_GetRankings_XML]
	@leagueName VARCHAR(100)
AS
--=============================================
-- Author: John Lin
-- Create date: 10/14/2014
-- Description: get default ranking for Native
-- Update:		07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @season_key INT
    DECLARE @week INT

    SELECT TOP 1 @season_key = season_key, @week = [week]
      FROM SportsEditDB.dbo.SMG_Polls
     WHERE league_key = @leagueName AND fixture_key = 'smg-usat'
     ORDER BY poll_date DESC

	DECLARE @polls TABLE (
	    poll_date        DATE,
        ranking          VARCHAR(100),
        record           VARCHAR(100),        
        points           VARCHAR(100),
        ranking_previous VARCHAR(100),
		-- extra
        name             VARCHAR(100)
	)

	INSERT INTO @polls (poll_date, ranking, name, record, points, ranking_previous)
	SELECT sp.poll_date, sp.ranking, st.team_first, CAST(sp.wins AS VARCHAR) + '-' + CAST(sp.losses AS VARCHAR), sp.points, ISNULL(sp.ranking_previous, 'NR')
	  FROM SportsEditDB.dbo.SMG_Polls sp
	 INNER JOIN dbo.SMG_Teams st
		ON st.season_key = sp.season_key AND st.team_abbreviation = sp.team_key
	 WHERE sp.league_key = @leagueName AND st.league_key = @league_key AND sp.season_key = @season_key
       AND sp.fixture_key = 'smg-usat' AND sp.[week] = @week


	-- additional info
	DECLARE @poll_date DATE
	DECLARE @dropped_out VARCHAR(MAX)
	DECLARE @votes_other VARCHAR(MAX)

    SELECT TOP 1 @poll_date = poll_date
      FROM @polls
     ORDER BY poll_date DESC

	SELECT @dropped_out = dropped_out, @votes_other = votes_other
      FROM SportsEditDB.dbo.SMG_Polls_Info
	 WHERE league_key = @leagueName AND fixture_key = 'smg-usat' AND poll_date = @poll_date



    SELECT 
    (
        SELECT ranking, name, record, points, ranking_previous
	      FROM @polls
		 ORDER BY CAST(ranking AS INT)
		   FOR XML RAW('poll'), TYPE
    ),
	(
		SELECT @poll_date AS poll_date, @dropped_out AS dropped_out, @votes_other AS votes_other
		   FOR XML RAW('info'), TYPE
	)
	FOR XML RAW('root'), TYPE

	
END


GO
