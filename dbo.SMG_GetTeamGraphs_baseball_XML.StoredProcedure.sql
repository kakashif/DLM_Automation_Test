USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamGraphs_baseball_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamGraphs_baseball_XML]
   @teamSlug       VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100)
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 09/29/2013
-- Description: get MLB team statistics graph leaders
-- Update:		09/30/2013 - ikenticus: adding default year_sub_season
--         		10/18/2013 - John Lin - code review
--         		10/22/2013 - John Lin - add team class
--         		01/08/2015 - John Lin - change team_key from league-average to l.mlb.com
--         		02/18/2015 - pkamat - change table from SMG_Team_Season_Statistics to SMG_Statistics
--				06/24/2015 - ikenticus - using league_key function, adding team_logo/rgb
--				09/03/2015 - ikenticus - SDI formatting
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

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')
	DECLARE @team_key VARCHAR(100)
	DECLARE @team_rgb VARCHAR(100)
	DECLARE @team_class VARCHAR(100)
    DECLARE @link VARCHAR(100) = '/sports/'	

    SELECT @team_key = team_key, @team_rgb = rgb
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug

    SELECT @team_class = 'mlb' + REPLACE(@team_key, @league_key + '-t.', '')

     
	INSERT INTO @stats (category, [column], value)
	SELECT category, [column], value 
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND 
		   team_key IN (@team_key, @league_key) AND category IN ('feed', 'league-average') AND player_key = 'team' AND
		   [column] IN ('average', 'runs-scored', 'home-runs', 'era', 'games-complete', 'shutouts')
		   	  
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
       SET ribbon = 'BATTING AVERAGE', ribbon_order = 1, label = 'Batting', label_order = 1,
           team_value = REPLACE(CAST(CAST(team_value AS DECIMAL(6,3)) AS VARCHAR), '0.', '.')
     WHERE ribbon = 'average'

    UPDATE @graphs
       SET ribbon = 'RUNS SCORED', ribbon_order = 2, label = 'Batting', label_order = 1
     WHERE ribbon = 'runs-scored'

    UPDATE @graphs
       SET ribbon = 'HOME RUNS', ribbon_order = 3, label = 'Batting', label_order = 1
     WHERE ribbon = 'home-runs'

    UPDATE @graphs
       SET ribbon = 'EARNED RUN AVERAGE', ribbon_order = 1, label = 'Pitching', label_order = 2,
           team_value = CAST(CAST(team_value AS DECIMAL(5,2)) AS VARCHAR)
     WHERE ribbon = 'era'

    UPDATE @graphs
       SET ribbon = 'COMPLETE GAMES', ribbon_order = 2, label = 'Pitching', label_order = 2
     WHERE ribbon = 'games-complete'

    UPDATE @graphs
       SET ribbon = 'SHUTOUTS', ribbon_order = 3, label = 'Pitching', label_order = 2
     WHERE ribbon = 'shutouts'


    SELECT @link = @link + 'mlb/' + @teamSlug + '/statistics/'


    SELECT
    (
    	SELECT @team_class AS team_class, @team_rgb AS team_rgb, l_tab.label, 
    	       (CASE
    	           WHEN l_tab.label = 'Batting' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/team/batting/'
    	           WHEN l_tab.label = 'Pitching' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/team/pitching/'
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
