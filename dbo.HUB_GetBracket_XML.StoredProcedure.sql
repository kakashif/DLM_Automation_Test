USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetBracket_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetBracket_XML]
    @sport VARCHAR(100),
    @year INT,
    @bracketKey VARCHAR(100),
    @guid VARCHAR(100)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 01/20/2015
-- Description:	get live or user bracket
-- Update: 03/16/2015 - John Lin - always link to preview
--         03/24/2015 - John Lin - no link if no start date
--         07/29/2015 - John Lin - SDI migration
--         08/03/2015 - John Lin - retrieve event_id using function
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @locked INT

    DECLARE @league_name VARCHAR(100) = 'ncaab'
    DECLARE @season_key INT = (@year - 1)

    IF (@bracketKey = 'live')
    BEGIN
        IF (@sport = 'womens-basketball')
        BEGIN
            SET @league_name = 'ncaaw'
        END
    END
    ELSE
    BEGIN
        SET @sport = 'mens-basketball'
        
        SELECT @league_name = league_name, @season_key = season_key
          FROM dbo.UGC_Bracket_Names
         WHERE bracket_key = @bracketKey

        IF (@league_name = 'ncaaw')
        BEGIN
            SET @sport = 'womens-basketball'
        END

        SELECT @locked = number 
          FROM dbo.UGC_GUID_Names
         WHERE [first] = @league_name AND [last] = CAST(@season_key AS VARCHAR) AND [guid] = 'locked-moc'

        -- bracket is public after tournament start
        IF (@locked = 0 AND @guid <> '')
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.UGC_Bracket_Names WHERE [guid] = @guid AND bracket_key = @bracketKey)
            BEGIN
                SELECT 'Access not allowed' AS [Message], '400' AS ReferenceNo
                   FOR XML PATH(''), ROOT('root')

                RETURN
            END
        END
    END
    

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@league_name)

    DECLARE @games TABLE 
	(
        match_id INT,
        region VARCHAR(100),
        region_advance VARCHAR(100),
        region_order INT,
        round_order INT,
        round_id VARCHAR(100),
        tv_coverage VARCHAR(100),
        site_name VARCHAR(100),
        -- live
        event_key VARCHAR(100),
        event_status VARCHAR(100),
        game_status VARCHAR(100),
        start_date_time_EST DATETIME,

        team_a_key VARCHAR(100),
        team_a_score VARCHAR(100),
        team_a_winner VARCHAR(100),
        team_a_abbr VARCHAR(100),
        team_b_key VARCHAR(100),
        team_b_score VARCHAR(100),
        team_b_winner VARCHAR(100),
        team_b_abbr VARCHAR(100),
        -- user
        user_a_abbr VARCHAR(100),
        user_b_abbr VARCHAR(100),
        -- calculation
        team_a_points VARCHAR(100),
        team_b_points VARCHAR(100),
                
        event_id VARCHAR(100),
        event_link VARCHAR(100),
        round_display VARCHAR(100)
	)
    INSERT INTO @games (match_id, region, event_key, team_a_key, team_b_key)
    SELECT match_id, region, event_key, team_a_key, team_b_key
      FROM dbo.Edit_Bracket
     WHERE league_key = @league_key AND season_key = @season_key
        
	UPDATE g
	   SET g.round_order = ebr.round_order, g.round_id = ebr.round_id, g.round_display = ebr.round_display
	  FROM @games g
	 INNER JOIN dbo.Edit_Bracket_Rounds ebr
	    ON ebr.league_name = @league_name AND ebr.match_id = g.match_id

	UPDATE g
	   SET g.region_order = ebr.region_order
	  FROM @games g
	 INNER JOIN dbo.Edit_Bracket_Regions ebr
	    ON ebr.league_name = @league_name AND ebr.season_key = @season_key AND ebr.region = g.region


    -- set away/home via feed
	UPDATE g
	   SET g.start_date_time_EST = ss.start_date_time_EST, g.event_status = ss.event_status, g.game_status = ss.game_status,
	       g.tv_coverage = ss.tv_coverage, g.site_name = ss.site_name
	  FROM @games g
	 INNER JOIN SportsDB.dbo.SMG_Schedules ss
	    ON ss.event_key = g.event_key

	UPDATE g
	   SET g.team_a_score = CAST(ss.away_team_score AS VARCHAR), g.team_b_score = CAST(ss.home_team_score AS VARCHAR)
	  FROM @games g
	 INNER JOIN SportsDB.dbo.SMG_Schedules ss
	    ON ss.event_key = g.event_key AND ss.away_team_key = g.team_a_key AND ss.home_team_key = g.team_b_key

	UPDATE g
	   SET g.team_a_score = CAST(ss.home_team_score AS VARCHAR), g.team_b_score = CAST(ss.away_team_score AS VARCHAR)
	  FROM @games g
	 INNER JOIN SportsDB.dbo.SMG_Schedules ss
	    ON ss.event_key = g.event_key AND ss.away_team_key = g.team_b_key AND ss.home_team_key = g.team_a_key

	UPDATE g
	   SET g.team_a_abbr = st.team_abbreviation
	  FROM @games g
	 INNER JOIN dbo.SMG_Teams st
	    ON st.season_key = @season_key AND st.team_key = g.team_a_key

	UPDATE g
	   SET g.team_b_abbr = st.team_abbreviation
	  FROM @games g
	 INNER JOIN dbo.SMG_Teams st
	    ON st.season_key = @season_key AND st.team_key = g.team_b_key

    UPDATE @games
       SET team_a_winner = '1', team_b_winner = '0'
     WHERE event_status = 'post-event' AND CAST(team_a_score AS INT) > CAST(team_b_score AS INT)

    UPDATE @games
       SET team_b_winner = '1', team_a_winner = '0'
     WHERE event_status = 'post-event' AND CAST(team_b_score AS INT) > CAST(team_a_score AS INT)

    -- LINK
    -- event id
    UPDATE @games
       SET event_id = dbo.SMG_fnEventId(event_key)
     
    UPDATE @games
       SET event_link = '/ncaa/' + @sport + '/event/' + CAST(@season_key AS VARCHAR) + '/' + event_id + '/' +
                          CASE
                              WHEN event_status = 'mid-event' THEN 'boxscore/'
                              WHEN event_status = 'post-event' THEN 'recap/'
                              ELSE 'preview/'
                          END
     WHERE event_key <> '' AND start_date_time_EST IS NOT NULL

    -- bracket user
    IF (@bracketKey <> 'live')
    BEGIN
        IF (@locked = 1)
        BEGIN
            -- locked
            UPDATE g
               SET g.user_a_abbr = b.team_a, g.user_b_abbr = b.team_b,
                   g.team_a_points = CAST(b.team_a_points AS VARCHAR), g.team_b_points = CAST(b.team_b_points AS VARCHAR)
              FROM @games g
             INNER JOIn dbo.UGC_Brackets b
                ON b.match_id = g.match_id AND b.bracket_key = @bracketKey
        END
        ELSE
        BEGIN
            DECLARE @payload XML

            SELECT @payload = payload
              FROM SportsEditDB.dbo.temp_Spool
             WHERE instance_key = @bracketKey

            DECLARE @bracket TABLE
            (
                match_id INT,
                user_a_abbr VARCHAR(100),
                user_b_abbr VARCHAR(100)
            )
            INSERT INTO @bracket (match_id, user_a_abbr, user_b_abbr)        
            SELECT node.value('(match_id/text())[1]', 'int'),
                   node.value('(team_a/text())[1]', 'varchar(100)'),
                   node.value('(team_b/text())[1]', 'varchar(100)')
              FROM @payload.nodes('/feed/picks') AS SMG(node)

            UPDATE g
               SET g.user_a_abbr = b.user_a_abbr, g.user_b_abbr = b.user_b_abbr
              FROM @games g
             INNER JOIn @bracket b
                ON b.match_id = g.match_id
        END
    END

    -- adjust
    UPDATE @games
       SET region_order = 0, region_advance = region
     WHERE match_id IN (64, 65, 66, 67)

    UPDATE @games
       SET region = 'Play-In'
     WHERE match_id IN (64, 65, 66, 67)

    UPDATE @games
       SET region_order = 5, region = 'Semi-Final'
     WHERE match_id IN (1, 2, 3)

    UPDATE @games
       SET region_order = 6, region = 'Champion'
     WHERE match_id = 0



    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
	(
           SELECT 'true' AS 'json:Array',
                  g_r.region,
                  (
                  SELECT 'true' AS 'json:Array',
                         g_o.round_display,
                         (
                             SELECT 'true' AS 'json:Array',
                                    g.match_id, g.game_status, g.event_status, g.region_advance, g.event_link, CAST(g.start_date_time_EST AS DATE) AS [date],
                                    ISNULL(g.tv_coverage, '') AS tv_coverage, ISNULL(g.site_name, '') AS site_name,
                                    (
                                        SELECT g.team_a_abbr AS live_abbr, g.user_a_abbr AS user_abbr,
                                               ISNULL(g.team_a_points, '') AS points,
                                               ISNULL(g.team_a_score, '') AS score, g.team_a_winner AS winner                                        
                                           FOR XML RAW('team_a'), TYPE                                    
                                    ),
                                    (
                                        SELECT g.team_b_abbr AS live_abbr, g.user_b_abbr AS user_abbr,
                                               ISNULL(g.team_b_points, '') AS points,
                                               ISNULL(g.team_b_score, '') AS score, g.team_b_winner AS winner
                                           FOR XML RAW('team_b'), TYPE
                                    )
                               FROM @games g
                              WHERE g.region = g_r.region AND g.round_id = g_o.round_id
                                FOR XML RAW('games'), TYPE                                    
                         )
                    FROM @games g_o
                   WHERE g_o.region = g_r.region
                   GROUP BY g_o.round_id, g_o.round_display, g_o.round_order
                   ORDER BY g_o.round_order ASC
                     FOR XML RAW('rounds'), TYPE
                  )
             FROM @games g_r
            GROUP BY g_r.region, g_r.region_order
            ORDER BY g_r.region_order ASC
              FOR XML RAW('regions'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

	    
    SET NOCOUNT OFF;
END




GO
