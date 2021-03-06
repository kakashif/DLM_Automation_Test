USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetPowerRankings_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetPowerRankings_XML] 
	@leagueName VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 12/19/2014
-- Description:	get power rankings, migrated to SportsEdit
-- Update: 01/21/2015 - ikenticus - limit PowerRankings to week_begin < today
--		   02/06/2015 - ikenticus - adding points column, if available
--		   02/20/2015 - ikenticus - commenting out the json helpers
--		   06/24/2015 - ikenticus: removing TSN/XTS league_key, updated logo
--         07/10/2015 - John Lin - STATS team records
-- =============================================
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @season_key INT
	DECLARE @week INT
	DECLARE @week_begin DATE

    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'

	SELECT TOP 1 @week = [week], @season_key = season_key, @week_begin = week_begin
	  FROM SportsEditDB.dbo.SMG_PowerRankings
	 WHERE league_key = @leagueName AND week_begin < GETDATE()
	 ORDER BY season_key DESC, [week] DESC

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
	INSERT INTO @rankings (team_key, ranking, ranking_previous, ranking_diff, ranking_mover, ranking_hilo, points, notes)
	SELECT team_key, ranking, ranking_previous, ranking_diff, ranking_mover, ranking_hilo, points, notes
	  FROM SportsEditDB.dbo.SMG_PowerRankings
	 WHERE league_key = @leagueName AND season_key = @season_key AND [week] = @week


	-- Update the team info
	UPDATE r
	   SET team_first = t.team_first, team_last = t.team_last, team_slug = t.team_slug,
		   team_class = @leagueName + REPLACE(t.team_key, @league_key + '-t.', ''),
		   team_logo = @logo_prefix + @leagueName + @logo_folder + '30/' + t.team_abbreviation + @logo_suffix,
		   team_logo_80 = @logo_prefix + @leagueName + @logo_folder + '80/' + t.team_abbreviation + @logo_suffix
	  FROM @rankings r
	 INNER JOIN SportsDB.dbo.SMG_Teams t
	    ON t.league_key = @league_key AND t.season_key = @season_key AND t.team_slug = r.team_key


	-- Update the team record
	UPDATE @rankings
	   SET record = SportsDB.dbo.SMG_fn_Team_Records(@leagueName, @season_key, team_key, @week_begin)
	 WHERE record IS NULL OR record = ''



	-- Build the reference node using poll_name
    DECLARE @ribbon		VARCHAR(100) = 'USA TODAY POWER RANKINGS'
    DECLARE @sub_ribbon	VARCHAR(100) = '(Published On: ' + CAST(@week_begin AS VARCHAR(100)) + ')'


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



    SELECT @credits AS credits, @video AS display_video, @week_begin AS published_on, @ribbon AS ribbon, @sub_ribbon AS sub_ribbon,
	(
		SELECT
		(
			SELECT  team_first, team_last, team_slug, team_rgb, team_logo_80, team_class, ranking, ranking_diff, ranking_hilo
			  FROM @rankings
			 WHERE ranking_mover = 'RISE'
			   FOR XML RAW('rise'), TYPE
		),
		(
			SELECT team_first, team_last, team_slug, team_rgb, team_logo_80, team_class, ranking, ranking_diff, ranking_hilo
			  FROM @rankings
			 WHERE ranking_mover = 'FALL'
			   FOR XML RAW('fall'), TYPE
		)
		FOR XML RAW('movers'), TYPE
	),
	(
		SELECT [column], display, [order], 'RANKINGS' AS ribbon
		  FROM @columns
		 ORDER BY [order]
		   FOR XML RAW('columns'), TYPE
	),
	(	
		SELECT team_first, team_last, team_slug, team_logo, team_class, record, points,
			   ranking, ranking_previous, ranking_diff, ranking_hilo, notes
		  FROM @rankings
		 ORDER BY ranking
		   FOR XML RAW('rows'), TYPE
	)
	FOR XML RAW('root'), TYPE


	SET NOCOUNT OFF;
END 

GO
