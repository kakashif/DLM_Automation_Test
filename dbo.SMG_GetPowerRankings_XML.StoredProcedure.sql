USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetPowerRankings_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetPowerRankings_XML] 
	@leagueName VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 12/19/2014
-- Description:	get power rankings, migrated to SportsEdit
-- Update: 01/21/2015 - ikenticus - limit PowerRankings to week_begin < today
--		   02/06/2015 - ikenticus - adding points column, if available
--		   02/20/2015 - ikenticus - commenting out the json helpers
--		   06/23/2015 - ikenticus - removing TSN/XTS league_key
--         07/10/2015 - John Lin - STATS team records
--		   08/03/2015 - ikenticus - fixing team records and logo logic
--		   09/08/2015 - ikenticus - use current week for team records
--		   09/15/2015 - ikenticus - rankings should be released around 11am instead of midnight
--		   09/16/2015 - ikenticus - week_begin should be DATE for published date, but DATETIME for team_record
--									team_logo needed for Biggest Movers with Video in addition to team_logo_80
-- =============================================
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @season_key INT
	DECLARE @week INT
	DECLARE @week_begin DATE

	SELECT TOP 1 @week = week, @season_key = season_key, @week_begin = week_begin
	  FROM SportsEditDB.dbo.SMG_PowerRankings
	 WHERE league_key = @leagueName AND week_begin < GETDATE()
	 ORDER BY season_key DESC, week DESC


	-- Create the Rankings table
	DECLARE @rankings TABLE (
	    team_class          VARCHAR(100),
	    team_first          VARCHAR(100),
	    team_last           VARCHAR(100),
	    team_slug           VARCHAR(100),
	    team_key	        VARCHAR(100),
	    team_logo_80		VARCHAR(100),
	    team_logo	        VARCHAR(100),
	    team_rgb	        VARCHAR(100),
	    ranking             INT,
	    ranking_previous	INT,
		ranking_diff		INT,
		ranking_mover		VARCHAR(100),
		ranking_hilo		VARCHAR(100),
        points              INT,
        record              VARCHAR(100),
		notes				VARCHAR(MAX)
	)

	INSERT INTO @rankings (team_slug, ranking, ranking_previous, ranking_diff, ranking_mover, ranking_hilo, points, notes)
	SELECT team_key, ranking, ranking_previous, ranking_diff, ranking_mover, ranking_hilo, points, notes
	  FROM SportsEditDB.dbo.SMG_PowerRankings
	 WHERE league_key = @leagueName AND season_key = @season_key AND week = @week


	-- Update the team info
	UPDATE r
	   SET team_first = t.team_first, team_last = t.team_last, team_key = t.team_key, team_rgb = t.rgb,
		   team_class = @leagueName + REPLACE(t.team_key, @league_key + '-t.', ''),
		   team_logo = dbo.SMG_fnTeamLogo(@leagueName, t.team_abbreviation, '30'),
		   team_logo_80 = dbo.SMG_fnTeamLogo(@leagueName, t.team_abbreviation, '80')
	  FROM @rankings AS r
	 INNER JOIN SportsDB.dbo.SMG_Teams AS t ON t.team_slug = r.team_slug
	 WHERE t.league_key = @league_key AND t.season_key = @season_key


	-- Update the team record
	UPDATE @rankings
	   SET record = SportsDB.dbo.SMG_fn_Team_Records(@leagueName, @season_key, team_key, DATEADD(HH, 11, CAST(@week_begin AS DATETIME)))
	 WHERE record IS NULL OR record = ''


	-- Build the reference node using poll_name
    DECLARE @reference TABLE
    (
        ribbon		VARCHAR(100),
        sub_ribbon	VARCHAR(100),
        ribbon_node	VARCHAR(100)
    )
    
	INSERT INTO @reference (ribbon_node, ribbon, sub_ribbon)
	SELECT  'rankings' AS ribbon_node, 'USA TODAY POWER RANKINGS' AS ribbon, '(Published On: ' + CAST(@week_begin AS VARCHAR(100)) + ')' AS sub_ribbon


	-- Build columns
    DECLARE @columns TABLE
    (
		[column]	VARCHAR(100),
        display		VARCHAR(100),
		[order]		INT
    )
    
	INSERT INTO @columns ([column], display, [order])
	VALUES ('ranking', 'RANK', 1),
		   ('team_slug', 'TEAM', 2),
		   ('record', 'RECORD', 3),
		   ('points', 'PTS', 4),
		   ('ranking_diff', 'CHANGE', 5),
		   ('ranking_hilo', 'HI/LOW', 6),
		   ('notes', 'NOTES', 7)

	IF NOT EXISTS (SELECT 1 FROM @rankings WHERE points IS NOT NULL)
	BEGIN
		DELETE @columns
		 WHERE display = 'PTS'
	END

    -- credits
    DECLARE @credits VARCHAR(MAX)

	SELECT @credits = credits
      FROM SportsEditDB.dbo.Feeds_Credits
     WHERE [type] = 'rankings-' + @leagueName


	-- video
	DECLARE @video INT = 0

	SELECT @video = [value]
	  FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
	 WHERE LOWER(league_name) = LOWER(@leagueName)
	   AND page_id = 'rankings' AND name = 'rankings_video'


	--;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT @credits AS credits, @video AS display_video, @week_begin AS published_on,
	(
		SELECT ribbon, ribbon_node, sub_ribbon
		  FROM @reference
		   FOR XML RAW('reference'), TYPE
	),
	(
		SELECT --'true' AS 'json:Array',
		(
			SELECT  team_first, team_last, team_slug, team_class, team_rgb, team_logo, team_logo_80, ranking, ranking_diff, ranking_hilo
			  FROM @rankings
			 WHERE ranking_mover = 'RISE'
			 ORDER BY CAST(ranking AS INT) ASC
			   FOR XML RAW('rise'), TYPE
		),
		(
			SELECT team_first, team_last, team_slug, team_class, team_rgb, team_logo, team_logo_80, ranking, ranking_diff, ranking_hilo
			  FROM @rankings
			 WHERE ranking_mover = 'FALL'
			 ORDER BY CAST(ranking AS INT) ASC
			   FOR XML RAW('fall'), TYPE
		)
		FOR XML RAW('movers'), TYPE
	),
	(
		SELECT [column], display, [order], 'RANKINGS' AS ribbon
		  FROM @columns
		 ORDER BY [order]
		   FOR XML RAW('rankings_column'), TYPE
	),
	(	
		SELECT team_first, team_last, team_slug, team_class, team_logo, record, points,
			   ranking, ranking_previous, ranking_diff, ranking_hilo, notes
		  FROM @rankings
		 ORDER BY ranking
		   FOR XML RAW('rankings'), TYPE
	)
	FOR XML RAW('root'), TYPE


	SET NOCOUNT OFF;
END 

GO
