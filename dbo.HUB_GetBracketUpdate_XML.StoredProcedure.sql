USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetBracketUpdate_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetBracketUpdate_XML]
    @sport VARCHAR(100),
    @year INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 03/09/2015
-- Description:	get mid event bracket
-- Update: 03/16/2015 - John Lin - remove mid event dup
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = 'l.ncaa.org.mbasket'
    DECLARE @league_name VARCHAR(100) = 'ncaab'
    DECLARE @season_key INT = (@year - 1)

    IF (@sport = 'womens-basketball')
    BEGIN
        SET @league_key = 'l.ncaa.org.wbasket'
        SET @league_name = 'ncaaw'
    END
    
    DECLARE @today DATE = CAST(GETDATE() AS DATE)
    DECLARE @tomorrow DATE = DATEADD(DAY, 1, @today)

    DECLARE @dup_games TABLE 
	(
        match_id INT
	)    
    DECLARE @games TABLE 
	(
        match_id INT,
        game_status VARCHAR(100),
        team_a_score INT,
        team_b_score INT,
        -- extra
        event_key VARCHAR(100),
        team_a_key VARCHAR(100),
        team_b_key VARCHAR(100)
	)
	-- on going game
    INSERT INTO @dup_games (match_id)
    SELECT eb.match_id
      FROM dbo.Edit_Bracket eb
     INNER JOIN dbo.SMG_Schedules ss
        ON ss.event_key = eb.event_key AND ss.event_status = 'mid-event'
     WHERE eb.league_key = @league_key AND eb.season_key = @season_key

    INSERT INTO @dup_games (match_id)
    SELECT eb.match_id
      FROM dbo.Edit_Bracket eb
     INNER JOIN dbo.SMG_Schedules ss
        ON ss.event_key = eb.event_key AND ss.start_date_time_EST BETWEEN @today AND @tomorrow
     WHERE eb.league_key = @league_key AND eb.season_key = @season_key

    IF NOT EXISTS (SELECT 1 FROM @dup_games)
    BEGIN
        SELECT '' AS games
           FOR XML PATH(''), ROOT('root')

        RETURN
    END
    
    

    INSERT INTO @games (match_id)
    SELECT match_id
      FROM @dup_games
     GROUP BY match_id

    UPDATE g
       SET g.event_key = eb.event_key, g.team_a_key = eb.team_a_key, g.team_b_key = eb.team_b_key
      FROM @games g
     INNER JOIN dbo.Edit_Bracket eb
        ON eb.league_key = @league_key AND eb.season_key = @season_key AND eb.match_id = g.match_id

	UPDATE g
	   SET g.team_a_score = ss.away_team_score, g.team_b_score = ss.home_team_score, g.game_status = ss.game_status
	  FROM @games g
	 INNER JOIN SportsDB.dbo.SMG_Schedules ss
	    ON ss.event_key = g.event_key AND ss.away_team_key = g.team_a_key AND ss.home_team_key = g.team_b_key

	UPDATE g
	   SET g.team_a_score = ss.home_team_score, g.team_b_score = ss.away_team_score, g.game_status = ss.game_status
	  FROM @games g
	 INNER JOIN SportsDB.dbo.SMG_Schedules ss
	    ON ss.event_key = g.event_key AND ss.away_team_key = g.team_b_key AND ss.home_team_key = g.team_a_key


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
	(
        SELECT 'true' AS 'json:Array',
               match_id, game_status, team_a_score, team_b_score
          FROM @games
           FOR XML RAW('games'), TYPE                                    
    )
    FOR XML PATH(''), ROOT('root')

	    
    SET NOCOUNT OFF;
END




GO
