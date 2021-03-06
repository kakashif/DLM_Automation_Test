USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamLeaders_football_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamLeaders_football_XML]
    @leagueName VARCHAR(100),
	@teamSlug VARCHAR(100),
	@seasonKey INT,
	@subSeasonType VARCHAR(100)
AS
--=============================================
-- Author:	  ikenticus
-- Create date:	09/29/2013
-- Description: get NFL team leaders
-- Update:		09/30/2013 - ikenticus: adding default year_sub_season
--              10/16/2013 - John Lin - code review
--              10/22/2013 - ikenticus: fixing link and adding team_class
--				01/30/2014 - ikenticus: text adjustments for product
--				02/07/2014 - ikenticus: forgot to adjust link associated with label 
--              02/17/2014 - cchiu    : text adjustments for product
--				02/20/2015 - ikenticus - migrating SMG_Player_Season_Statistics to SMG_Statistics
--              04/08/2015 - John Lin - new head shot logic
--				06/24/2015 - ikenticus - STATS migration
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

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @team_key VARCHAR(100)
	DECLARE @team_rgb VARCHAR(100)
	DECLARE @team_class VARCHAR(100)
    DECLARE @link VARCHAR(100) = '/sports/'
	
    SELECT @team_key = team_key, @team_class = team_abbreviation, @team_rgb = rgb
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug

    IF (@leagueName = 'nfl')
    BEGIN
        SELECT @team_class = 'nfl' + REPLACE(@team_key, @league_key + '-t.', '')
    END
     

    -- OFFENSE
    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
	SELECT TOP 1 'PASSING', player_key, value + ' YDS', 'Offensive', 1
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	       team_key = @team_key AND [column] = 'passes-yards-gross' AND player_key <> 'team'
     ORDER BY CONVERT(FLOAT, value) DESC

    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
	SELECT TOP 1 'RUSHING', player_key, value + ' YDS', 'Offensive', 1
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	       team_key = @team_key AND [column] = 'rushes-yards' AND player_key <> 'team'
     ORDER BY CONVERT(FLOAT, value) DESC

    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
	SELECT TOP 1 'RECEIVING', player_key, value + ' YDS', 'Offensive', 1
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	       team_key = @team_key AND [column] = 'receptions-yards' AND player_key <> 'team'
     ORDER BY CONVERT(FLOAT, value) DESC

    -- DEFENSE
    IF (@league_key = 'l.nfl.com')
    BEGIN
        INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
        SELECT TOP 1 'TACKLES', player_key, value + ' TACK', 'Defensive', 2
	      FROM SportsEditDB.dbo.SMG_Statistics
    	 WHERE league_key = 'l.nfl.com' AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	           team_key = @team_key AND [column] = 'tackles-total' AND player_key <> 'team'
          ORDER BY CONVERT(FLOAT, value) DESC

        INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
        SELECT TOP 1 'SACKS', player_key, value + ' SACKS', 'Defensive', 2
    	  FROM SportsEditDB.dbo.SMG_Statistics
	     WHERE league_key = 'l.nfl.com' AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	           team_key = @team_key AND [column] = 'sacks-total' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, value) DESC

        INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
        SELECT TOP 1 'INTERCEPTIONS', player_key, value + ' INT', 'Defensive', 2
	      FROM SportsEditDB.dbo.SMG_Statistics
    	 WHERE league_key = 'l.nfl.com' AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	           team_key = @team_key AND [column] = 'interceptions-total' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, value) DESC
    END
    
    -- SPECIAL TEAMS
    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'KICKING', player_key, value + ' FG%', 'Special Teams', 3
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	       team_key = @team_key AND [column] = 'field-goals-percentage' AND player_key <> 'team'
     ORDER BY CONVERT(FLOAT, value) DESC

    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'PUNTING', player_key, value + ' AVG YDS', 'Special Teams', 3
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	       team_key = @team_key AND [column] = 'punts-average' AND player_key <> 'team'
     ORDER BY CONVERT(FLOAT, value) DESC

    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'KICK RETURNING', player_key, REPLACE(CONVERT(VARCHAR, CAST(value AS MONEY), 1), '.00', '') + ' YDS', 'Special Teams', 3
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	       team_key = @team_key AND [column] = 'returns-kickoff-yards' AND player_key <> 'team'
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

    IF (@league_key = 'l.nfl.com')
    BEGIN
    	UPDATE l
	       SET l.head_shot = sr.head_shot + '120x120/' + sr.[filename]
    	  FROM @leaders l
	     INNER JOIN dbo.SMG_Rosters sr
		    ON sr.league_key = 'l.nfl.com' AND sr.season_key = @seasonKey AND sr.team_key = @team_key AND sr.player_key = l.player_key AND
		       sr.head_shot IS NOT NULL AND sr.[filename] IS NOT NULL
    END

    SELECT @link = @link + @leagueName + '/' + @teamSlug + '/statistics/'


    SELECT
    (
    	SELECT l_tab.label,
    	       (CASE
    	           WHEN l_tab.label = 'Offensive' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/player/offense/'
    	           WHEN l_tab.label = 'Defensive' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/player/defense/'
    	           WHEN l_tab.label = 'Special Teams' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/player/special-teams/'    	           
    	           ELSE @link
    	       END) AS link,
    	(
    		SELECT @team_key AS team_key, @team_rgb AS team_rgb, @team_class AS team_class, l.ribbon, l.name, l.uniform_number, l.position_regular, l.value, l.head_shot
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
