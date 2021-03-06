USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAABLines_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetNCAABLines_XML]
    @year INT,
    @month INT,
    @day INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 03/18/2015
-- Description:	get ncaab lines
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @start_date DATETIME = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-' + CAST(@day AS VARCHAR) AS DATETIME)
    DECLARE @end_date DATETIME = DATEADD(DAY, 4, @start_date)
   
    DECLARE @games TABLE 
	(
	    season_key INT,
        event_key VARCHAR(100),
        odds VARCHAR(100),
        away_key VARCHAR(100),
        home_key VARCHAR(100),
        away_name VARCHAR(100),
        home_name VARCHAR(100),
        [date] DATE
	)
    INSERT INTO @games (season_key, event_key, odds, away_key, home_key, [date])
    SELECT season_key, event_key, odds, away_team_key, home_team_key, CAST(start_date_time_EST AS DATE)
      FROM dbo.SMG_Schedules
     WHERE league_key = 'l.ncaa.org.mbasket' AND start_date_time_EST BETWEEN @start_date AND @end_date

	UPDATE g
	   SET g.away_name = st.team_first
	  FROM @games g
	 INNER JOIN dbo.SMG_Teams st
	    ON st.season_key = g.season_key AND st.team_key = g.away_key

	UPDATE g
	   SET g.home_name = st.team_first
	  FROM @games g
	 INNER JOIN dbo.SMG_Teams st
	    ON st.season_key = g.season_key AND st.team_key = g.home_key
/*
    UPDATE @games
       SET team_a_winner = '1', team_b_winner = '0'
     WHERE event_status = 'post-event' AND CAST(team_a_score AS INT) > CAST(team_b_score AS INT)

    UPDATE @games
       SET team_b_winner = '1', team_a_winner = '0'
     WHERE event_status = 'post-event' AND CAST(team_b_score AS INT) > CAST(team_a_score AS INT)
*/



    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
	(
		          SELECT 'true' AS 'json:Array',
		                 g.[date], g.odds,
			             (
				         SELECT a.away_name
						   FROM @games a
						  WHERE a.event_key = g.event_key
						    FOR XML RAW('away_team'), TYPE                   
						 ),
						 ( 
						 SELECT h.home_name
						   FROM @games h
						  WHERE h.event_key = g.event_key
						    FOR XML RAW('home_team'), TYPE
						 )
					  FROM @games g
					 ORDER BY g.[date] ASC
					   FOR XML RAW('events'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

	    
    SET NOCOUNT OFF;
END




GO
