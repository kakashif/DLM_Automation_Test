USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnGetNCAAFFilter]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[SMG_fnGetNCAAFFilter] (
    @seasonKey INT,
    @week      VARCHAR(100),
    @filter    VARCHAR(100),
    @page      VARCHAR(100)
)
RETURNS @filters TABLE (
    id VARCHAR(100),
    display VARCHAR(100)
)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 04/02/2014
-- Description:	get ncaaf filter
-- Update: 12/16/2014 - John Lin - add playoffs
--         03/10/2015 - John Lin - deprecate SMG_NCAA table
--		   07/01/2015 - ikenticus - using league_key function, using converted SMG_Polls*
--         08/18/2015 - John Lin - use conference display
-- =============================================
BEGIN
    INSERT INTO @filters (id, display)
    VALUES ('div1.a', 'All FBS (I-A)')

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('ncaaf')

    IF (@week NOT IN ('bowls', 'playoffs'))
    BEGIN
        DECLARE @events TABLE
        (
            away_key  VARCHAR(100),
            away_abbr VARCHAR(100),
            away_rank VARCHAR(100),
            away_conf VARCHAR(100),
            home_key  VARCHAR(100),
            home_abbr VARCHAR(100),
            home_rank VARCHAR(100),
            home_conf VARCHAR(100),
            [week]    VARCHAR(100)
        )
        IF (@page = 'schedules' AND @week = 'all')
        BEGIN
            INSERT INTO @events (away_key, home_key, [week])
            SELECT away_team_key, home_team_key, [week]
              FROM dbo.SMG_Schedules
              WHERE league_key = @league_key AND season_key = @seasonKey AND [week] <> 'bowls'
        END
        ELSE
        BEGIN
            INSERT INTO @events (away_key, home_key, [week])
            SELECT away_team_key, home_team_key, [week]
              FROM dbo.SMG_Schedules
              WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = @week
        END

		UPDATE e
		   SET away_abbr = t.team_abbreviation
		  FROM @events AS e
		 INNER JOIN dbo.SMG_Teams AS t ON t.team_key = e.away_key
		 WHERE t.league_key = @league_key AND t.season_key = @seasonKey

		UPDATE e
		   SET home_abbr = t.team_abbreviation
		  FROM @events AS e
		 INNER JOIN dbo.SMG_Teams AS t ON t.team_key = e.home_key
		 WHERE t.league_key = @league_key AND t.season_key = @seasonKey

        -- assume no poll
        DECLARE @max_week INT
        
        SELECT TOP 1 @max_week = [week]
          FROM SportsEditDB.dbo.SMG_Polls
         WHERE league_key = 'ncaaf' AND season_key = @seasonKey AND fixture_key = 'smg-usat'
         ORDER BY [week] DESC
        
        -- set to max week
        UPDATE e
           SET e.away_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = 'ncaaf' AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.away_abbr AND sp.[week] = @max_week
               
        UPDATE e
           SET e.home_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = 'ncaaf' AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.home_abbr AND sp.[week] = @max_week

        -- set to correct week 
        UPDATE e
           SET e.away_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = 'ncaaf' AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.away_abbr AND sp.[week] = CAST(e.[week] AS INT)
               
        UPDATE e
           SET e.home_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = 'ncaaf' AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.home_abbr AND sp.[week] = CAST(e.[week] AS INT)

        

        IF EXISTS (SELECT 1 FROM @events WHERE CAST(ISNULL(away_rank, '') AS INT) + CAST(ISNULL(home_rank, '') AS INT) > 0)
        BEGIN
            INSERT INTO @filters (id, display)
            VALUES ('top25', 'Top 25')
        END
                
        UPDATE e
           SET e.away_conf = st.conference_key
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = e.away_key

        UPDATE e
           SET e.home_conf = st.conference_key
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = e.home_key

        INSERT INTO @filters (id, display)
        SELECT SportsEditDB.dbo.SMG_fnSlugifyName(sl.conference_display), sl.conference_display
          FROM dbo.SMG_Leagues sl
         INNER JOIN @events e
            ON sl.conference_key IN (e.away_conf, e.home_conf)
         WHERE sl.league_key = @league_key AND sl.season_key = @seasonKey AND sl.tier = 1
         GROUP BY sl.conference_key, sl.conference_display, sl.conference_order
         ORDER BY sl.conference_order ASC
    END
           
    RETURN
END

GO
