USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[GDP_Roster_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GDP_Roster_XML]
    @leagueName VARCHAR(100),
	@teamSlug VARCHAR(100)
AS
--=============================================
-- Author: John Lin
-- Create date:	07/07/2015
-- Description: get active roster for GDP
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

/* DEPRECATED

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    DECLARE @team_key VARCHAR(100)

    SELECT TOP 1 @season_key = r.season_key, @team_key = t.team_key
      FROM dbo.SMG_Rosters r
     INNER JOIN dbo.SMG_Teams t
        ON t.season_key = r.season_key AND t.team_key = r.team_key AND t.team_slug = @teamSlug
     WHERE r.league_key = @league_key AND r.phase_status  = 'active'
     ORDER BY r.season_key DESC

	DECLARE @roster TABLE (
		player_key     VARCHAR(100),
		id             VARCHAR(100),
		uniform_number VARCHAR(100),
		position       VARCHAR(100),
		height         VARCHAR(100), -- mlb, nba, nfl, ncaa
		[weight]       INT,
        head_shot      VARCHAR(200),
        [filename]     VARCHAR(100),
		first_name     VARCHAR(100),
		last_name      VARCHAR(100),
		[status]       VARCHAR(100), -- nba, nhl
		class          VARCHAR(100), -- ncaa
		-- extra
		age            INT,          -- mlb
		bats           VARCHAR(100), -- mlb
		birth          VARCHAR(100), -- mlb, ncaa
		captain        VARCHAR(100), -- nhl,
		college        VARCHAR(100), -- nba, nfl
		dob            VARCHAR(100), -- nfl, nhl
		experience     VARCHAR(100), -- nfl
		shoots         VARCHAR(100), -- nhl
		throws         VARCHAR(100)  -- mlb
	)
	
    IF (@leagueName = 'mlb')
    BEGIN
        INSERT INTO @roster (player_key, uniform_number, position, height, [weight], head_shot, [filename])
        SELECT player_key, uniform_number, position_regular, height, [weight], head_shot, [filename]
          FROM dbo.SMG_Rosters
         WHERE season_key = @season_key AND team_key = @team_key AND phase_status = 'active'

        UPDATE r
           SET r.first_name = sp.first_name, r.last_name = sp.last_name,
               r.age = DATEDIFF(YY, sp.date_of_birth, GETDATE()), r.college = sp.college_name,
               r.bats = sp.shooting_batting_hand, r.birth = sp.birth_place, r.throws = sp.throwing_hand
          FROM @roster r
         INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = r.player_key
    END
    ELSE IF (@leagueName IN ('nba', 'wnba'))
    BEGIN
        INSERT INTO @roster (player_key, uniform_number, position, height, [weight], head_shot, [filename], [status])
        SELECT player_key, uniform_number, position_regular, height, [weight], head_shot, [filename], phase_status
          FROM dbo.SMG_Rosters
         WHERE season_key = @season_key AND team_key = @team_key AND phase_status IN ('active', 'injured')

        UPDATE r
           SET r.first_name = sp.first_name, r.last_name = sp.last_name,
               r.college = sp.college_name
          FROM @roster r
         INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = r.player_key
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        INSERT INTO @roster (player_key, uniform_number, position, height, [weight], head_shot, [filename])
        SELECT player_key, uniform_number, position_regular, height, [weight], head_shot, [filename]
          FROM dbo.SMG_Rosters
         WHERE season_key = @season_key AND team_key = @team_key AND phase_status = 'active'

        UPDATE r
           SET r.first_name = sp.first_name, r.last_name = sp.last_name,
               r.college = sp.college_name, r.experience = sp.duration,
               r.dob = CAST(DATEPART(MONTH, sp.date_of_birth) AS VARCHAR) + '/' +
                       CAST(DATEPART(DAY, sp.date_of_birth) AS VARCHAR) + '/' +
                       CAST(DATEPART(YEAR, sp.date_of_birth) AS VARCHAR)
          FROM @roster r
         INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = r.player_key
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        INSERT INTO @roster (player_key, uniform_number, position, [weight], head_shot, [filename], [status])
        SELECT player_key, uniform_number, position_regular, [weight], head_shot, [filename], phase_status
          FROM dbo.SMG_Rosters
         WHERE season_key = @season_key AND team_key = @team_key

        UPDATE r
           SET r.first_name = sp.first_name, r.last_name = sp.last_name,
               r.dob = CAST(DATEPART(MONTH, sp.date_of_birth) AS VARCHAR) + '/' +
                       CAST(DATEPART(DAY, sp.date_of_birth) AS VARCHAR) + '/' +
                       CAST(DATEPART(YEAR, sp.date_of_birth) AS VARCHAR),
               r.shoots = sp.shooting_batting_hand
          FROM @roster r
         INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = r.player_key
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        INSERT INTO @roster (player_key, uniform_number, position, height, [weight], class)
        SELECT player_key, uniform_number, position_regular, height, [weight], subphase_type
          FROM dbo.SMG_Rosters
         WHERE season_key = @season_key AND team_key = @team_key AND phase_status = 'active'

        UPDATE r
           SET r.first_name = sp.first_name, r.last_name = sp.last_name, r.birth = sp.birth_place
          FROM @roster r
         INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = r.player_key
    END

    UPDATE @roster
       SET uniform_number = ''
     WHERE uniform_number IS NULL OR uniform_number = 0

    UPDATE @roster
       SET head_shot = 'http://www.gannett-cdn.com/media/SMG/' + head_shot + '120x120/' + [filename]
     WHERE head_shot IS NOT NULL AND [filename] IS NOT NULL

    UPDATE @roster
       SET id = REPLACE(player_key, @league_key + '-p.', '')



    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT
    (
	    SELECT 'true' AS 'json:Array',
	           id, uniform_number, position, height, [weight], head_shot, first_name, last_name, 
	           [status], class, age, bats, birth, captain, college, dob, experience, shoots, throws
    	  FROM @roster
    	 ORDER BY last_name ASC
           FOR XML RAW('roster'), TYPE
    )
	FOR XML RAW('root'), TYPE

*/
	
END


GO
