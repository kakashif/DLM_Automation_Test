USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamGraphs_hockey_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamGraphs_hockey_XML]
   @teamSlug      VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100)
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 09/30/2013
-- Description: get NHL team statistics graph leaders
-- Update: 10/21/2013 - John Lin - code review
--         10/22/2013 - John Lin - add team class
--         01/08/2015 - John Lin - change team_key from league-average to l.nhl.com
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

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('nhl')
	DECLARE @team_key VARCHAR(100)
	DECLARE @team_rgb VARCHAR(100)
	DECLARE @team_class VARCHAR(100)
    DECLARE @link VARCHAR(100) = '/sports/'
	
    SELECT @team_key = team_key, @team_rgb = rgb
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug

    SELECT @team_class = 'nhl' + REPLACE(@team_key, @league_key + '-t.', '')


	INSERT INTO @stats (category, [column], value)
	SELECT category, [column], value 
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND 
		   team_key IN (@team_key, @league_key) AND category IN ('feed', 'league-average') AND player_key = 'team' AND
		   [column] IN ('goals', 'goals-per-game', 'shots-per-game', 'goals-allowed', 'shots-allowed-per-game', 'shutouts',
		                'power-play-percentage', 'penalty-killing-percentage', 'penalty-minutes')

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
       SET ribbon = 'GOALS', ribbon_order = 1, label = 'Offense', label_order = 1
     WHERE ribbon = 'goals'

    UPDATE @graphs
       SET ribbon = 'GOALS PER GAME', ribbon_order = 2, label = 'Offense', label_order = 1
     WHERE ribbon = 'goals-per-game'

    UPDATE @graphs
       SET ribbon = 'SHOTS PER GAME', ribbon_order = 3, label = 'Offense', label_order = 1
     WHERE ribbon = 'shots-per-game'

    UPDATE @graphs
       SET ribbon = 'GOALS ALLOWED', ribbon_order = 1, label = 'Goaltending', label_order = 2
     WHERE ribbon = 'goals-allowed'

    UPDATE @graphs
       SET ribbon = 'SHOTS ALLOWED PER GAME', ribbon_order = 2, label = 'Goaltending', label_order = 2
     WHERE ribbon = 'shots-allowed-per-game'

    UPDATE @graphs
       SET ribbon = 'SHUTOUTS', ribbon_order = 3, label = 'Goaltending', label_order = 2
     WHERE ribbon = 'shutouts'

    UPDATE @graphs
       SET ribbon = 'POWER PLAY %', ribbon_order = 1, label = 'Special Teams', label_order = 3
     WHERE ribbon = 'power-play-percentage'

    UPDATE @graphs
       SET ribbon = 'PENALTY KILL %', ribbon_order = 2, label = 'Special Teams', label_order = 3
     WHERE ribbon = 'penalty-killing-percentage'

    UPDATE @graphs
       SET ribbon = 'PENALTY MINUTES', ribbon_order = 3, label = 'Special Teams', label_order = 3
     WHERE ribbon = 'penalty-minutes'


    SELECT @link = @link + 'nhl/' + @teamSlug + '/statistics/'


    SELECT
    (
    	SELECT @team_class AS team_class, @team_rgb AS team_rgb, l_tab.label, 
    	       (CASE
    	           WHEN l_tab.label = 'Offense' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/team/offense/'
    	           WHEN l_tab.label = 'Goaltending' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/team/goaltending/'
    	           WHEN l_tab.label = 'Special Teams' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/team/special-teams/'
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
