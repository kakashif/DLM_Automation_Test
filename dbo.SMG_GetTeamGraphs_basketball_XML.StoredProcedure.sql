USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamGraphs_basketball_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamGraphs_basketball_XML]
   @leagueName    VARCHAR(100),
   @teamSlug      VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100)
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 09/30/2013
-- Description: get NCAAB team statistics graph leaders
-- Update:		09/30/2013 - ikenticus: adding default year_sub_season
--         10/18/2013 - John Lin - code review
--         10/22/2013 - John Lin - add team class
--         06/02/2014 - John Lin - modify text
--         01/08/2015 - John Lin - change team_key from league-average to @league_key
--         02/17/2015 - Prashant Kamat - change field goal % from .XXX to XX.X
--         02/20/2015 - ikenticus - migrating SMG_Team_Season_Statistics to SMG_Statistics
--		   06/24/2015 - ikenticus - using league_key function, adding team_logo/rgb
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @stats TABLE
    (
        category VARCHAR(100),
        [column] VARCHAR(100), 
        value    VARCHAR(100)
    )

    DECLARE @graphs TABLE
    (
        ribbon         VARCHAR(100),
        team_value     VARCHAR(100),
        league_value   VARCHAR(100),
        team_percent   VARCHAR(100),
        league_percent VARCHAR(100),
        ribbon_order   INT,
        label          VARCHAR(100),
        label_order    INT
    )

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @team_key VARCHAR(100)
	DECLARE @team_rgb VARCHAR(100)
	DECLARE @team_class VARCHAR(100)
    DECLARE @link VARCHAR(100) = '/sports/'

    SELECT @team_key = team_key, @team_class = team_abbreviation, @team_rgb = rgb
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug

    IF (@leagueName IN ('nba', 'wnba'))
    BEGIN
        SELECT @team_class = @leagueName + REPLACE(@team_key, @league_key + '-t.', '')
    END

     
	INSERT INTO @stats (category, [column], value)
	SELECT category, [column], value 
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND 
		   team_key IN (@team_key, @league_key) AND category IN ('feed', 'league-average') AND player_key = 'team' AND
		   [column] IN ('points-scored-total-per-game', 'assists-per-game', 'rebounds-per-game', 'blocks-per-game', 'steals-per-game')

	INSERT INTO @stats (category, [column], value)
	SELECT category, [column], CONVERT(FLOAT, value)*100
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND 
		   team_key IN (@team_key, @league_key) AND category IN ('feed', 'league-average') AND
		   [column] IN ('field-goals-percentage') AND player_key = 'team'
		   	  

    INSERT INTO @graphs (ribbon, team_value, league_value) 
    SELECT p.[column], [feed], [league-average]
      FROM (SELECT category, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[category] IN ([feed], [league-average])) AS p


    -- calculate
    UPDATE @graphs
       SET team_percent = '100'
       
    UPDATE @graphs
       SET league_percent = '100'
     WHERE CAST(league_value AS FLOAT) > CAST(team_value AS FLOAT)

    UPDATE @graphs
       SET team_percent = ROUND(CAST(team_value AS FLOAT) / CAST(league_value AS FLOAT) * 100, 3)
     WHERE league_percent = '100'

    UPDATE @graphs
       SET league_percent = ROUND(CAST(league_value AS FLOAT) / CAST(team_value AS FLOAT) * 100, 3)
     WHERE team_percent = '100'
     
     
    UPDATE @graphs
       SET ribbon = 'POINTS PER GAME', ribbon_order = 1, label = 'Offense', label_order = 1
     WHERE ribbon = 'points-scored-total-per-game'

    UPDATE @graphs
       SET ribbon = 'ASSISTS PER GAME', ribbon_order = 2, label = 'Offense', label_order = 1
     WHERE ribbon = 'assists-per-game'

    UPDATE @graphs
       SET ribbon = 'FIELD GOAL %', ribbon_order = 3, label = 'Offense', label_order = 1
     WHERE ribbon = 'field-goals-percentage'

    UPDATE @graphs
       SET ribbon = 'REBOUNDS PER GAME', ribbon_order = 1, label = 'Defense', label_order = 2
     WHERE ribbon = 'rebounds-per-game'

    UPDATE @graphs
       SET ribbon = 'BLOCKS PER GAME', ribbon_order = 2, label = 'Defense', label_order = 2
     WHERE ribbon = 'blocks-per-game'

    UPDATE @graphs
       SET ribbon = 'STEALS PER GAME', ribbon_order = 3, label = 'Defense', label_order = 2
     WHERE ribbon = 'steals-per-game'


    SELECT @link = @link + @leagueName + '/' + @teamSlug + '/statistics/'


    SELECT
    (
    	SELECT @team_class AS team_class, @team_rgb AS team_rgb, l_tab.label, 
    	       (CASE
    	           WHEN l_tab.label = 'Offense' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/team/offense/'
    	           WHEN l_tab.label = 'Defense' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/team/defense/'
    	           ELSE @link
    	       END) AS link,
    	(
    		SELECT l.ribbon, l.team_value, l.league_value, l.team_percent, l.league_percent
		      FROM @graphs l
    		 WHERE l.label = l_tab.label
    		ORDER BY l.ribbon_order ASC
	    	   FOR XML RAW('tab'), TYPE
	    )
	    FROM @graphs l_tab
	    GROUP BY l_tab.label, l_tab.label_order
	    ORDER BY l_tab.label_order ASC
	    FOR XML RAW('graph'), TYPE
	)	
	FOR XML RAW('root'), TYPE
		
END

GO
