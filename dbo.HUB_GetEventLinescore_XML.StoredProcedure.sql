USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetEventLinescore_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetEventLinescore_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 07/29/2014
-- Description: get event linescore
-- Update       07/29/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END    
    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @game_status VARCHAR(100)
    DECLARE @away_key VARCHAR(100)
    DECLARE @home_key VARCHAR(100)

    DECLARE @away_first VARCHAR(100)
    DECLARE @home_first VARCHAR(100)
       
    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @game_status = game_status, @away_key = away_team_key, @home_key = home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR) 

    IF (@event_status = 'pre-event')
    BEGIN
        SELECT '' AS linescore
           FOR XML PATH(''), ROOT('root')

        RETURN
    END



    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        SELECT @away_first = team_first
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @away_key

        SELECT @home_first = team_first
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @home_key
    END
    ELSE
    BEGIN
        SELECT @away_first = team_last
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @away_key

        SELECT @home_first = team_last
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @home_key
    END

    DECLARE @linescore TABLE
    (
        period INT,
        period_value VARCHAR(100),
        away_value VARCHAR(100),
        home_value VARCHAR(100)
    )

    INSERT INTO @linescore (period, period_value, away_value, home_value)
    SELECT period, period_value, away_value, home_value
      FROM dbo.SMG_Periods
     WHERE event_key = @event_key



    SELECT
	(
        SELECT @event_status AS event_status, @game_status AS game_status,
               (
                   SELECT period_value AS periods
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE
               ),
               (
                   SELECT @away_first AS [first],
                          (
                              SELECT away_value AS sub_score
                                FROM @linescore
                               ORDER BY period ASC
                                 FOR XML PATH(''), TYPE
                              
                          )
                      FOR XML RAW('away'), TYPE
               ),
               (
                   SELECT @home_first AS [first],
                          (
                              SELECT home_value AS sub_score
                                FROM @linescore
                               ORDER BY period ASC
                                 FOR XML PATH(''), TYPE
                              
                          )
                      FOR XML RAW('home'), TYPE
               )
           FOR XML RAW('linescore'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

        
    SET NOCOUNT OFF;
END

GO
