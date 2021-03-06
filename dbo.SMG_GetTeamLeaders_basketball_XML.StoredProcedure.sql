USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamLeaders_basketball_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamLeaders_basketball_XML]
    @leagueName VARCHAR(100),
	@teamSlug VARCHAR(100),
	@seasonKey INT,
	@subSeasonType VARCHAR(100)
AS
--=============================================
-- Author:	  ikenticus
-- Create date:	09/29/2013
-- Description: get NBA team leaders
-- Update:		09/30/2013 - ikenticus: adding default year_sub_season
--              10/16/2013 - John Lin - code review
--              10/22/2013 - ikenticus: fixing link and adding team_class
--              12/02/2013 - ikenticus: missing ribbon/label for FG%
--				01/30/2014 - ikenticus: text adjustments for product
--				02/07/2014 - ikenticus: forgot to adjust link associated with label
--              02/10/2014 - cchiu    : text adjustments for product
--              02/11/2014 - cchiu    : convert field goal float into percentage
--         		02/17/2015 - pkamat	  : change field goal % from .XXX to XX.X
--				02/20/2015 - ikenticus - migrating SMG_Player_Season_Statistics to SMG_Statistics
--              04/08/2015 - John Lin - new head shot logic
--				06/24/2015 - ikenticus - STATS migration
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

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
	DECLARE @team_key VARCHAR(100)
	DECLARE @team_rgb VARCHAR(100)
	DECLARE @team_class VARCHAR(100)
    DECLARE @link VARCHAR(100) = NULL
	
    SELECT @team_key = team_key, @team_class= team_abbreviation, @team_rgb = rgb
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug

    IF (@leagueName IN ('nba', 'wnba'))
    BEGIN
        SELECT @team_class = @leagueName + REPLACE(@team_key, @league_key + '-t.', '')
    END
     

    -- OFFENSE
    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'POINTS', spss.player_key, spss.value + ' PPG', 'Offensive', 1
	  FROM SportsEditDB.dbo.SMG_Statistics spss
	 INNER JOIN SportsEditDB.dbo.SMG_Statistics spss_q
	    ON spss_q.league_key = spss.league_key AND spss_q.season_key = spss.season_key AND spss_q.sub_season_type = spss.sub_season_type AND
	       spss_q.team_key = spss.team_key AND spss_q.player_key = spss.player_key AND spss_q.[column] = 'points-scored-for-qualify' AND spss_q.value = '1'	       
	 WHERE spss.league_key = @league_key AND spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType AND
	       spss.team_key = @team_key AND spss.[column] = 'points-scored-per-game' AND spss.player_key <> 'team'
     ORDER BY CONVERT(FLOAT, spss.value) DESC

    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'ASSISTS', spss.player_key, spss.value + ' APG', 'Offensive', 1
	  FROM SportsEditDB.dbo.SMG_Statistics spss
	 INNER JOIN SportsEditDB.dbo.SMG_Statistics spss_q
	    ON spss_q.league_key = spss.league_key AND spss_q.season_key = spss.season_key AND spss_q.sub_season_type = spss.sub_season_type AND
	       spss_q.team_key = spss.team_key AND spss_q.player_key = spss.player_key AND spss_q.[column] = 'assists-total-qualify' AND spss_q.value = '1'	       
	 WHERE spss.league_key = @league_key AND spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType AND
	       spss.team_key = @team_key AND spss.[column] = 'assists-total-per-game' AND spss.player_key <> 'team'
     ORDER BY CONVERT(FLOAT, spss.value) DESC

    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'FIELD GOAL PERCENTAGE', player_key, CONVERT(VARCHAR, CONVERT(FLOAT, value)*100) + ' FG%', 'Offensive', 1
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND
	       team_key = @team_key AND [column] = 'field-goals-percentage' AND player_key <> 'team'
     ORDER BY CONVERT(FLOAT, value) DESC

    -- DEFENSE
    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'REBOUNDS', spss.player_key, spss.value + ' RPG', 'Defensive', 2
	  FROM SportsEditDB.dbo.SMG_Statistics spss
	 INNER JOIN SportsEditDB.dbo.SMG_Statistics spss_q
	    ON spss_q.league_key = spss.league_key AND spss_q.season_key = spss.season_key AND spss_q.sub_season_type = spss.sub_season_type AND
	       spss_q.team_key = spss.team_key AND spss_q.player_key = spss.player_key AND spss_q.[column] = 'rebounds-total-qualify' AND spss_q.value = '1'	       
	 WHERE spss.league_key = @league_key AND spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType AND
	       spss.team_key = @team_key AND spss.[column] = 'rebounds-per-game' AND spss.player_key <> 'team'
     ORDER BY CONVERT(FLOAT, spss.value) DESC

    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'BLOCKS', spss.player_key, spss.value + ' BPG', 'Defensive', 2
	  FROM SportsEditDB.dbo.SMG_Statistics spss
	 INNER JOIN SportsEditDB.dbo.SMG_Statistics spss_q
	    ON spss_q.league_key = spss.league_key AND spss_q.season_key = spss.season_key AND spss_q.sub_season_type = spss.sub_season_type AND
	       spss_q.team_key = spss.team_key AND spss_q.player_key = spss.player_key AND spss_q.[column] = 'blocks-total-qualify' AND spss_q.value = '1'	       
	 WHERE spss.league_key = @league_key AND spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType AND
	       spss.team_key = @team_key AND spss.[column] = 'blocks-per-game' AND spss.player_key <> 'team'
     ORDER BY CONVERT(FLOAT, spss.value) DESC

    INSERT INTO @leaders (ribbon, player_key, value, label, label_order)
    SELECT TOP 1 'STEALS', spss.player_key, spss.value + ' SPG', 'Defensive', 2
	  FROM SportsEditDB.dbo.SMG_Statistics spss
	 INNER JOIN SportsEditDB.dbo.SMG_Statistics spss_q
	    ON spss_q.league_key = spss.league_key AND spss_q.season_key = spss.season_key AND spss_q.sub_season_type = spss.sub_season_type AND
	       spss_q.team_key = spss.team_key AND spss_q.player_key = spss.player_key AND spss_q.[column] = 'steals-total-qualify' AND spss_q.value = '1'	       
	 WHERE spss.league_key = @league_key AND spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType AND
	       spss.team_key = @team_key AND spss.[column] = 'steals-per-game' AND spss.player_key <> 'team'
     ORDER BY CONVERT(FLOAT, spss.value) DESC


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
    

    IF (@leagueName IN ('nba', 'wnba'))
    BEGIN        
    	UPDATE l
	       SET l.head_shot = sr.head_shot + '120x120/' + sr.[filename]
    	  FROM @leaders l
	     INNER JOIN dbo.SMG_Rosters sr
		    ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = @team_key AND sr.player_key = l.player_key AND
    		   sr.head_shot IS NOT NULL AND sr.[filename] IS NOT NULL
    END


	IF (@leagueName != 'ncaab')
	BEGIN
		SELECT @link = '/sports/' + @leagueName + '/' + @teamSlug + '/statistics/'
	END

    SELECT
    (
    	SELECT l_tab.label,
    	       (CASE
    	           WHEN l_tab.label = 'Offensive' AND @leagueName != 'ncaab' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/player/offense/'
    	           WHEN l_tab.label = 'Defensive' AND @leagueName != 'ncaab' THEN @link + CAST(@seasonKey AS VARCHAR(100)) + '/' + @subSeasonType + '/player/defense/'
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
