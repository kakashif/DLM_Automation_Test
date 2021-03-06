USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetSummaryByConference_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[HUB_GetSummaryByConference_XML]
   @leagueName VARCHAR(100),
   @parameter VARCHAR(100),
   @startEpoch INT,
   @endEpoch   INT
AS
--=============================================
-- Author: John Lin
-- Create date: 08/08/2014
-- Description: get score summeries by conference
-- Update: 08/13/2014 - John Lin - parameter can be conference or slug
--         09/08/2014 - John Lin - gmt_time update
--         09/10/2014 - John Lin - fix score issue
--         07/29/2015 - John Lin - SDI migration
--         08/03/2015 - John Lin - retrieve event_id using function
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    -- NEED TO PUT INTO A TABLE
    DECLARE @conference_key VARCHAR(100) = NULL
    
    IF (@parameter = 'sec')
    BEGIN
        SET @conference_key = '/sport/football/conference:12'
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)   
    DECLARE @start_date_time VARCHAR(100) = REPLACE(REPLACE(CONVERT(VARCHAR, DATEADD(SECOND, @startEpoch - (4 * 60 * 60), '19700101'), 126), '-', ''), ':', '') + '-0500'
    DECLARE @end_date_time VARCHAR(100) = REPLACE(REPLACE(CONVERT(VARCHAR, DATEADD(SECOND, @endEpoch - (4 * 60 * 60), '19700101'), 126), '-', ''), ':', '') + '-0500'
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/60/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'

    DECLARE @summary TABLE
    (
        sequence_number       INT,
        team_key              VARCHAR(100),
        event_key             VARCHAR(100),
        period_value          INT,
        period_time_remaining VARCHAR(100),
        play_type             VARCHAR(100),
        play_score            INT,
        away_score            INT,
        home_score            INT,
        play_description      VARCHAR(MAX),
        date_time             VARCHAR(100),
        -- extra
        end_position          INT DEFAULT 1,
        team_name             VARCHAR(100),
        team_logo             VARCHAR(100),
        game_status           VARCHAR(100),
        gmt_time              INT,
        season_key            INT,
        event_id              VARCHAR(100),
        dt                    VARCHAR(100),
        away_first            VARCHAR(100),
        away_key              VARCHAR(100),
        away_slug             VARCHAR(100),
        away_conference       VARCHAR(100),
        home_first            VARCHAR(100),
        home_key              VARCHAR(100),
        home_slug             VARCHAR(100),
        home_conference       VARCHAR(100),
        event_link            VARCHAR(100),
        xp_sequence_number    INT
    )
    
    INSERT INTO @summary (sequence_number, team_key, event_key, period_value, period_time_remaining, play_type, play_score, away_score, home_score, play_description, date_time)
    SELECT sequence_number, team_key, event_key, period_value, period_time_remaining, play_type, play_score, away_score, home_score, value, date_time
      FROM SportsDB.dbo.SMG_Plays_NFL
     WHERE date_time BETWEEN @start_date_time AND @end_date_time AND play_type IN ('touchdown', 'field-goal', 'safety', 'two-point-conversion', 'extra-point')

    -- remove
    UPDATE s
       SET s.season_key = ss.season_key, s.away_key = ss.away_team_key, s.home_key = ss.home_team_key
      FROM @summary s
     INNER JOIN dbo.SMG_Schedules ss
        ON ss.event_key = s.event_key

    UPDATE s
       SET s.away_conference = st.conference_key, s.away_first = st.team_first, s.away_slug = st.team_slug
      FROM @summary s
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = s.season_key AND st.team_key = s.away_key

    UPDATE s
       SET s.home_conference = st.conference_key, s.home_first = st.team_first, s.home_slug = st.team_slug
      FROM @summary s
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = s.season_key AND st.team_key = s.home_key

    IF (@conference_key IS NOT NULL)
    BEGIN
        UPDATE @summary
           SET away_conference = ''
         WHERE away_conference IS NULL

        UPDATE @summary
           SET home_conference = ''
         WHERE home_conference IS NULL

        DELETE @summary
         WHERE @conference_key NOT IN (away_conference, home_conference)
    END
    ELSE
    BEGIN
        UPDATE @summary
           SET away_slug = ''
         WHERE away_slug IS NULL

        UPDATE @summary
           SET home_slug = ''
         WHERE home_slug IS NULL

        DELETE @summary
         WHERE @parameter NOT IN (away_slug, home_slug)
    END

    IF NOT EXISTS (SELECT 1 FROM @summary)
    BEGIN
    	SELECT '' AS summary
           FOR XML PATH(''), ROOT('root')

        RETURN
    END

    
    UPDATE s
       SET s.team_name = st.team_first, s.team_logo = @logo_prefix + st.team_abbreviation + @logo_suffix
      FROM @summary s
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = s.season_key AND st.team_key = s.team_key

    -- extra point
    UPDATE s
       SET s.xp_sequence_number = (SELECT TOP 1 xp.sequence_number
                                     FROM @summary xp
                                    WHERE xp.event_key = s.event_key AND xp.play_type IN ('extra-point', 'two-point-conversion') AND
                                          xp.sequence_number > s.sequence_number
                                    ORDER BY xp.sequence_number ASC)
      FROM @summary s
     WHERE s.play_type = 'touchdown'

    UPDATE s
       SET s.away_score = xp.away_score, s.home_score = xp.home_score
      FROM @summary s
     INNER JOIN @summary xp
        ON xp.event_key = s.event_key AND xp.sequence_number = s.xp_sequence_number
     WHERE s.play_type = 'touchdown'

    DELETE @summary
     WHERE play_type IN ('extra-point', 'two-point-conversion')

    -- back fill no score  
    update @summary
       set xp_sequence_number = null

         
    UPDATE s
       SET s.xp_sequence_number = (SELECT TOP 1 xp.sequence_number
                                     FROM @summary xp
                                    WHERE xp.event_key = s.event_key AND xp.play_score > 0 AND 
                                          xp.sequence_number < s.sequence_number
                                    ORDER BY xp.sequence_number DESC)
      FROM @summary s
     WHERE s.play_score = 0

    UPDATE s
       SET s.away_score = xp.away_score, s.home_score = xp.home_score
      FROM @summary s
     INNER JOIN @summary xp
        ON xp.event_key = s.event_key AND xp.sequence_number = s.xp_sequence_number
     WHERE s.play_score = 0

     
    -- set end position to dash
    UPDATE @summary
       SET end_position = CHARINDEX(' - ', play_description) + 3
     WHERE CHARINDEX(' - ', play_description) > 0 

    -- date time                               
    UPDATE @summary
       SET dt = REPLACE(LEFT(date_time, 15), 'T', ' ')


    UPDATE @summary
       SET dt = LEFT(dt, 11) + ':' + SUBSTRING(dt, 12, 2) + ':' + RIGHT(dt, 2)

    -- event id
    -- event id
    UPDATE @summary
       SET event_id = dbo.SMG_fnEventId(event_key)


    UPDATE @summary
       SET play_description = SUBSTRING(play_description, end_position, LEN(play_description)),
           game_status = CASE
                             WHEN period_value = 1 THEN '1st ' + period_time_remaining
                             WHEN period_value = 2 THEN '2nd ' + period_time_remaining
                             WHEN period_value = 3 THEN '3rd ' + period_time_remaining
                             WHEN period_value = 4 THEN '4th ' + period_time_remaining
                             ELSE CAST((period_value - 4) AS VARCHAR) + 'OT' + period_time_remaining
                         END,
           gmt_time = DATEDIFF(SECOND, '1970-01-01 00:00:00', CAST(dt AS DATETIME)) + (4 * 60 * 60),
           event_link = '/ncaa/football/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/',
           play_type = CASE
                           WHEN play_type = 'field-goal' THEN 'Field Goal'
                           WHEN play_type = 'safety' THEN 'Safety'
                           WHEN play_type = 'touchdown' THEN 'Touchdown'
                           ELSE 'remove'
                       END

    DELETE @summary
     WHERE play_type = 'remove'       



    SELECT
	(
	    SELECT team_name, team_logo, away_first, home_first, play_type, play_description, game_status, away_score, home_score, gmt_time, event_link
	      FROM @summary
	     ORDER BY gmt_time DESC
	       FOR XML RAW('summary'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
            
    SET NOCOUNT OFF 
END

GO
