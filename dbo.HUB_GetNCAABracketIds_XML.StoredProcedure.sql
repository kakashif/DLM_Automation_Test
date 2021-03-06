USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAABracketIds_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[HUB_GetNCAABracketIds_XML]
   @leagueName VARCHAR(100),
   @year INT
AS
--=============================================
-- Author: John Lin
-- Create date: 03/12/2015
-- Description: get NCAA bracket events
-- Update: 07/29/2015 - John Lin - SDI migration
--         08/03/2015 - John Lin - retrieve event_id using function
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)   
    DECLARE @season_key INT = (@year - 1)
   
    DECLARE @events TABLE
    (
        event_key VARCHAR(100),
        away_key  VARCHAR(100),
        home_key  VARCHAR(100),
        [date]    DATE,
	    -- extra       
        id        VARCHAR(100),
        away      VARCHAR(100),
        home      VARCHAR(100)
    )

    INSERT INTO @events (event_key, [date], away_key, home_key)
    SELECT event_key, CAST(start_date_time_EST AS DATE), away_team_key, home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND [week] = 'ncaa'

    IF NOT EXISTS (SELECT 1 FROM @events)
    BEGIN
        SELECT '' AS schedule
           FOR XML PATH(''), ROOT('root')
           
        RETURN
    END
    
    

    UPDATE e
       SET e.away = st.team_first
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @season_key AND st.team_key = e.away_key

    UPDATE e
       SET e.home = st.team_first
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @season_key AND st.team_key = e.home_key

    -- event id
    UPDATE @events
       SET id = dbo.SMG_fnEventId(event_key)

         
	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
	(
        SELECT 'true' AS 'json:Array',
			   [date], id, away, home
          FROM @events e
         ORDER BY e.[date] ASC
           FOR XML RAW('schedule'), TYPE
    )
    FOR XML PATH(''), ROOT('root')       

            
    SET NOCOUNT OFF 
END


GO
