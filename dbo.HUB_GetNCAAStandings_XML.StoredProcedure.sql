USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAAStandings_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[HUB_GetNCAAStandings_XML]
   @conference VARCHAR(100),
   @sport VARCHAR(100)
AS
--=============================================
-- Author: John Lin
-- Create date: 07/22/2014
-- Description: get NCAA standings
-- Update: 09/05/2014 - John Lin - additional order requirement
--                               - team rank and sort
--         09/23/2014 - John Lin - use latest week from poll for ranking
--         10/14/2014 - John Lin - remove league key from SMG_Standings
--		   07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
--         09/08/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/60/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'

    -- NEED TO PUT INTO A TABLE
    DECLARE @conference_key VARCHAR(100)
    
    IF (@conference = 'sec')
    BEGIN
        SET @conference_key = '/sport/football/conference:12'
    END

    DECLARE @league_name VARCHAR(100)
    DECLARE @season_key INT
    DECLARE @week VARCHAR(100)

    IF (@sport = 'mens-basketball')
    BEGIN
        SELECT @league_name = 'ncaab', @season_key = season_key
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaab' AND page = 'standings'

        SELECT TOP 1 @week = [week]
          FROM SportsEditDB.dbo.SMG_Polls
         WHERE league_key = 'ncaab' AND fixture_key = 'smg-usat'
         ORDER BY poll_date DESC
    END
    ELSE IF (@sport = 'football')
    BEGIN
		SELECT @league_name = 'ncaaf', @season_key = season_key
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaaf' AND page = 'standings'

        SELECT TOP 1 @week = [week]
          FROM SportsEditDB.dbo.SMG_Polls
         WHERE league_key = 'ncaaf' AND fixture_key = 'smg-usat'
         ORDER BY poll_date DESC
    END
    ELSE IF (@sport = 'womens-basketball')
    BEGIN
        SELECT @league_name = 'ncaaw', @season_key = season_key
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaaw' AND page = 'standings'

        SELECT TOP 1 @week = [week]
          FROM SportsEditDB.dbo.SMG_Polls
         WHERE league_key = 'ncaaw' AND fixture_key = 'smg-usat'
         ORDER BY poll_date DESC
    END

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@league_name)
    
    DECLARE @columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        column_name    VARCHAR(100),
        column_display VARCHAR(100)
    )
    DECLARE @stats TABLE
    (
        team_key   VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
          
    INSERT INTO @columns (column_name, column_display)
    VALUES ('name', ''), ('conf_record', 'CONF'), ('record', 'ALL')
        
    INSERT INTO @stats (team_key, [column], value)
    SELECT ss.team_key, ss.[column], ss.value
      FROM SportsEditDB.dbo.SMG_Standings ss
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = ss.season_key AND st.team_key = ss.team_key AND st.conference_key = @conference_key
     WHERE ss.season_key = @season_key AND ss.[column] IN ('away-wins', 'away-losses', 'home-wins', 'home-losses', 'conference-wins', 'conference-losses')

    DECLARE @standings TABLE
    (
        division_key VARCHAR(100),
        division_display VARCHAR(100),
        division_order INT,
        team_key VARCHAR(100),
        -- render
        name VARCHAR(100),
        wins INT,
        losses INT,
        conference_wins INT,
        conference_losses INT,
        -- extra
        [away-wins] INT,
        [away-losses] INT,
        [home-wins] INT,
        [home-losses] INT,
        team_abbr VARCHAR(100),
        team_slug VARCHAR(100),
        team_rank VARCHAR(100)
    )
            
    INSERT INTO @standings (team_key, [away-wins], [home-wins], [away-losses], [home-losses], conference_wins, conference_losses)
    SELECT p.team_key, ISNULL([away-wins], 0), ISNULL([home-wins], 0), ISNULL([away-losses], 0), ISNULL([home-losses], 0),
           ISNULL([conference-wins], 0), ISNULL([conference-losses], 0)
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([away-wins], [away-losses], [home-wins], [home-losses], [conference-wins], [conference-losses])) AS p

    UPDATE @standings
       SET wins = [away-wins] + [home-wins],
           losses = [away-losses] + [home-losses]

    UPDATE s
       SET s.division_key = sl.division_key,
           s.division_display = sl.division_display,
           s.division_order = sl.division_order,
           s.name = st.team_first,
           s.team_abbr = st.team_abbreviation,
           s.team_slug = st.team_slug
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.team_key = s.team_key AND st.league_key = @league_key AND st.season_key = @season_key AND st.conference_key = @conference_key
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key

    -- RANK
    IF (@week NOT IN ('bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi'))
    BEGIN
        UPDATE s
           SET s.team_rank = sp.ranking
          FROM @standings s    
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @league_name AND sp.season_key = @season_key AND sp.team_key = s.team_abbr
		   AND sp.[week] = @week AND fixture_key = 'smg-usat'
    END
    ELSE IF (@sport <> 'football' AND @week = 'ncaa')
    BEGIN
        UPDATE s
           SET s.team_rank = enbt.seed
          FROM @standings s    
         INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
            ON enbt.season_key = @season_key AND enbt.team_key = s.team_key
    END
     

    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)    
    SELECT
    (
        SELECT 'true' AS 'json:Array',
        (
	        SELECT column_name, CASE WHEN column_name = 'name' THEN cd_s.division_display ELSE column_display END AS column_display
		      FROM @columns
		     ORDER BY id ASC
		       FOR XML PATH('columns'), TYPE
	    ),
        (
            SELECT s.name, CAST(s.conference_wins AS VARCHAR) + '-' + CAST(s.conference_losses AS VARCHAR) AS conf_record,
                   CAST(s.wins AS VARCHAR) + '-' + CAST(s.losses AS VARCHAR) AS record, s.team_slug,
                   @logo_prefix + s.team_abbr + @logo_suffix AS logo, s.team_rank,
                   '/ncaa/sec/' + team_slug + '/' + @sport + '/' AS team_link
              FROM @standings s
             WHERE s.division_key = cd_s.division_key
             ORDER BY CAST(s.conference_wins AS INT) DESC, CAST(s.conference_losses AS INT) ASC,
                      CAST(s.wins AS INT) DESC, CAST(s.losses AS INT) ASC,
                      CAST(s.team_rank AS INT) ASC
               FOR XML RAW('rows'), TYPE
        )
        FROM @standings cd_s
       GROUP BY cd_s.division_key, cd_s.division_display, cd_s.division_order
       ORDER BY cd_s.division_order ASC
         FOR XML RAW('standings'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
                
    SET NOCOUNT OFF 
END


GO
