USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Teams_new_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[LOC_Teams_new_XML]
   @leagueName VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 04/20/2015
  -- Description: get team list for USCP
  -- Update: 08/07/2015 - John Lin - SDI migration
  --         09/03/2015 - John Lin - return only teams in schedule
  --         09/28/2015 - John Lin - add team rank for NCAA
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
   	DECLARE @season_key INT
   	DECLARE @week VARCHAR(100)

    SELECT @season_key = team_season_key, @week = [week]
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'

    DECLARE @team_keys TABLE
    (
        team_key VARCHAR(100)
    )
    INSERT INTO @team_keys (team_key)
    SELECT away_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key

    INSERT INTO @team_keys (team_key)
    SELECT home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key

	DECLARE @teams TABLE
	(
	    conference_key VARCHAR(100),
	    conference VARCHAR(100),
	    division_key VARCHAR(100),
	    division VARCHAR(100),
	    team_key VARCHAR(100),
	    team_id VARCHAR(100),
        team_first VARCHAR(100),
        team_last VARCHAR(100),
        team_abbr VARCHAR(100),
        team_logo VARCHAR(100),
        team_slug VARCHAR(100),
        team_rank VARCHAR(100),
        -- exhibition
        league_key VARCHAR(100),
        league_name VARCHAR(100)
	)
	INSERT INTO @teams (team_key)
	SELECT team_key
	  FROM @team_keys
	 GROUP BY team_key

    UPDATE t
       SET t.conference_key = st.conference_key, t.division_key = st.division_key, t.team_first = st.team_first, t.team_last = st.team_last,
           t.team_abbr = st.team_abbreviation, t.team_slug = st.team_slug
      FROM @teams t
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @season_key AND st.team_key = t.team_key
	 
    UPDATE t
       SET t.conference = sl.conference_display, t.division = sl.division_name
      FROM @teams t
     INNER JOIN dbo.SMG_Leagues sl
        ON sl.league_key = @league_key AND sl.season_key = @season_key AND
           sl.conference_key = t.conference_key AND ISNULL(sl.division_key, '') = ISNULL(t.division_key, '')

    UPDATE @teams
       SET team_logo = dbo.SMG_fnTeamLogo(@leagueName, team_abbr, '60')
     WHERE team_abbr IS NOT NULL

    UPDATE @teams
       SET team_id = dbo.SMG_fnEventId(team_key)

    -- RANK
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        DECLARE @poll_week INT
        
        IF (ISNUMERIC(@week) = 1 AND EXISTS (SELECT 1
                                               FROM SportsEditDB.dbo.SMG_Polls
                                              WHERE league_key = @leagueName AND season_key = @season_key AND fixture_key = 'smg-usat' AND [week] = CAST(@week AS INT)))
        BEGIN
            SET @poll_week = CAST(@week AS INT)
        END
        ELSE
        BEGIN
            SELECT TOP 1 @poll_week = [week]
              FROM SportsEditDB.dbo.SMG_Polls
             WHERE league_key = @leagueName AND season_key = @season_key AND fixture_key = 'smg-usat'
             ORDER BY [week] DESC
        END
        
        UPDATE t
           SET t.team_rank = sp.ranking
          FROM @teams t
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.season_key = @season_key AND sp.fixture_key = 'smg-usat' AND sp.team_key = t.team_abbr AND sp.[week] = @poll_week              
       
        IF (@leagueName IN ('ncaab', 'ncaaw'))
        BEGIN
            UPDATE t
               SET t.team_rank = enbt.seed
              FROM @teams t
             INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
                ON enbt.league_key = @league_key AND enbt.season_key = @season_key AND enbt.team_key = t.team_key
             WHERE @week IS NOT NULL AND @week = 'ncaa'
        END

        UPDATE @teams
           SET team_rank = ''
         WHERE team_rank IS NULL
    END
 


    SELECT
    (
        SELECT conference, division, team_key, team_id, team_first, team_last, team_abbr, team_logo, team_slug, team_rank
	      FROM @teams
           FOR XML PATH('teams'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

END

GO
