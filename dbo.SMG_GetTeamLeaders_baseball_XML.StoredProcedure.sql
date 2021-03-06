USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamLeaders_baseball_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamLeaders_baseball_XML]
	@teamSlug VARCHAR(100),
	@seasonKey INT,
	@subSeasonType VARCHAR(100)
AS
--=============================================
-- Author:	  ikenticus
-- Create date:	09/27/2013
-- Description: get MLB team leaders
-- Update:		09/30/2013 - ikenticus: adding default year_sub_season
--              10/16/2013 - John Lin - code review
--              10/22/2013 - ikenticus: fixing link and adding team_class 
--         		02/18/2015 - pkamat - change table from SMG_Team_Season_Statistics to SMG_Statistics
--         		02/23/2015 - pkamat - change criteria to get ERA and Batting Average leader
--              04/08/2015 - John Lin - new head shot logic
--              06/18/2015 - John Lin - STATS migration
--				09/03/2015 - ikenticus - SDI formatting
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @leaders TABLE
    (
        player_key       VARCHAR(100),
        name             VARCHAR(100),
        uniform_number   VARCHAR(100),
        position_regular VARCHAR(100),
        ribbon           VARCHAR(100),
        value            VARCHAR(100),
        label            VARCHAR(100),
        label_order      INT,
        head_shot        VARCHAR(100)        
    )

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')
	DECLARE @team_key VARCHAR(100)
	DECLARE @team_rgb VARCHAR(100)
    DECLARE @link VARCHAR(100) = '/sports/'	

    SELECT @team_key = team_key, @team_rgb = rgb
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug
     
    -- BATTING
    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'BATTING AVERAGE', player_key, REPLACE(CAST(CAST(value AS DECIMAL(6,3)) AS VARCHAR), '0.', '.') + ' AVG', 'Batting', 1
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	       team_key = @team_key AND [column] = 'average' AND player_key IN
			(SELECT player_key
			   FROM SportsEditDB.dbo.SMG_Statistics
			  WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
				   team_key = @team_key AND [column] = 'average-qualify' AND player_key <> 'team' AND [value] = '1' 
			)
     ORDER BY CONVERT(FLOAT, value) DESC

    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'HOME RUNS', player_key, value + ' HR', 'Batting', 1
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND
		   sub_season_type = @subSeasonType AND team_key = @team_key AND [column] = 'home-runs' AND player_key <> 'team'
     ORDER BY CONVERT(FLOAT, value) DESC

    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'RUNS BATTED IN', player_key, value + ' RBI', 'Batting', 1
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND
		   sub_season_type = @subSeasonType AND team_key = @team_key AND [column] = 'rbi' AND player_key <> 'team'
     ORDER BY CONVERT(FLOAT, value) DESC

    -- PITCHING
    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'WINS', player_key, value + ' W', 'Pitching', 2
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	       team_key = @team_key AND [column] = 'wins' AND player_key <> 'team'
     ORDER BY CONVERT(FLOAT, value) DESC


    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'EARNED RUN AVERAGE', player_key, CAST(CAST(value AS DECIMAL(5,2)) AS VARCHAR) + ' ERA', 'Pitching', 2
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	       team_key = @team_key AND [column] = 'era' AND player_key IN 
			(SELECT player_key
			   FROM SportsEditDB.dbo.SMG_Statistics
			  WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
				   team_key = @team_key AND [column] = 'era-qualify' AND player_key <> 'team' AND [value] = '1' 
			)
     ORDER BY CONVERT(FLOAT, value) ASC

    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'SAVES', player_key, value + ' SV', 'Pitching', 2
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	       team_key = @team_key AND [column] = 'saves' AND player_key <> 'team'
     ORDER BY CONVERT(FLOAT, value) DESC


	UPDATE l
	   SET l.position_regular = sr.position_regular
	  FROM @leaders l
	 INNER JOIN dbo.SMG_Rosters sr
		ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = @team_key AND sr.player_key = l.player_key
					   
	UPDATE l
	   SET l.name = LEFT(sp.first_name, 1) + '. ' + sp.last_name
	  FROM @leaders l
	 INNER JOIN dbo.SMG_Players sp
		ON sp.player_key = l.player_key

	UPDATE l
	   SET l.uniform_number = sr.uniform_number
	  FROM @leaders l
	 INNER JOIN dbo.SMG_Rosters sr
		ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = @team_key AND sr.player_key = l.player_key

	UPDATE l
	   SET l.head_shot = sr.head_shot + '120x120/' + sr.[filename]
	  FROM @leaders l
	 INNER JOIN dbo.SMG_Rosters sr
		ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = @team_key AND sr.player_key = l.player_key AND
		   sr.head_shot IS NOT NULL AND sr.[filename] IS NOT NULL

    SELECT @link = @link + 'mlb/' + @teamSlug + '/statistics/'


    SELECT
    (
    	SELECT l_tab.label,
    	       (CASE
    	           WHEN l_tab.label = 'Batting' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/player/batting/'
    	           WHEN l_tab.label = 'Pitching' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/player/pitching/'
    	           ELSE @link
    	       END) AS link,
    	(
    		SELECT @team_key AS team_key, @team_rgb AS team_rgb, l.ribbon, l.name, l.uniform_number, l.position_regular, l.value, l.head_shot, l.player_key
		      FROM @leaders l
    		 WHERE l.label = l_tab.label
	    	   FOR XML RAW('tab'), TYPE
	    )
	    FROM @leaders l_tab
	    GROUP BY l_tab.label, l_tab.label_order
	    ORDER BY l_tab.label_order ASC
	    FOR XML RAW('leader'), TYPE
	)	
	FOR XML RAW('root'), TYPE
	
END


GO
