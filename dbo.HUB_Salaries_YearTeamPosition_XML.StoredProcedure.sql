USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_Salaries_YearTeamPosition_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_Salaries_YearTeamPosition_XML]
	@leagueName VARCHAR(100),
	@year       INT,
	@teamSlug   VARCHAR(100),
	@position   VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 01/08/2015
-- Description:	get Team Salaries using new SMG_Salaries table
--				02/18/2015 - ikenticus: adding editorial overrides
--				03/23/2015 - ikenticus: forgot to add position to ribbon
--              03/30/2015 - John Lin - seperate salaries and finances
--              04/02/2015 - John Lin - use next available season for team
--              04/03/2015 - John Lin - fix team link, reduce code
--              04/07/2015 - John Lin - statistics using regular season
--              04/08/2015 - John Lin - new head shot logic
--				04/21/2015 - ikenticus: excluding status=CUT players
--				07/27/2015 - ikenticus - migrating to decoupled player/team keys
-- =============================================
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


	DECLARE @league_key VARCHAR(100) = SportsDB.dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @embargo_season INT

   	-- embargo latest season
   	SELECT @embargo_season = season_key
      FROM SportsDB.dbo.SMG_Default_Dates
   	 WHERE league_key = @leagueName AND page = 'salaries'

   	IF (@embargo_season IS NULL)
    BEGIN
	    SET @embargo_season = YEAR(GETDATE())
    END

    IF (@year = 0 OR @year > @embargo_season)
    BEGIN   
        SET @year = @embargo_season
    END

    -- column
	DECLARE @columns TABLE
	(
		display		VARCHAR(100),
		[column]	VARCHAR(100)
	)
	INSERT INTO @columns (display, [column])
	VALUES ('Name', 'name'), ('POS', 'pos'), ('Salary', 'salary'), ('Years', 'year'), ('Total Value', 'total_value')

	IF (@leagueName = 'mlb')
	BEGIN
		INSERT INTO @columns (display, [column])
		VALUES ('Avg Annual', 'avg_annual')
	END

    -- row
	DECLARE @salaries TABLE
	(
		team_key	 VARCHAR(100),
		player_key	 VARCHAR(100),
		player_slug	 VARCHAR(100),
		name         VARCHAR(100),
		team_abbr    VARCHAR(100),
		position 	 VARCHAR(100),
		salary_money MONEY,
		years        VARCHAR(100),
		total_money  MONEY,
		annual_money MONEY,
        -- display
        salary       VARCHAR(100),
     	total        VARCHAR(100),
     	annual       VARCHAR(100),
		-- extra
		team_slug	 VARCHAR(100),
		team_link    VARCHAR(100)
	)
    DECLARE @team_key VARCHAR(100)

    IF (@teamSlug = 'all')
    BEGIN
        INSERT INTO @salaries (player_slug, team_key, salary_money, years, total_money, annual_money, position, name)
	    SELECT player_key, team_key, salary, CAST(contract_years AS VARCHAR(2)) + ' (' + contract_range + ')', contract_amount,
			   ROUND(salary_average, 0), override_position, override_firstname + ' ' + override_lastname
	      FROM SportsEditDB.dbo.SMG_Salaries
	     WHERE league_key = @league_key AND season_key = @year AND player_key <> 'team' AND ISNULL([status], '') <> 'CUT' AND salary > 0
    END
    ELSE
    BEGIN
        SELECT @team_key = team_key
	      FROM dbo.SMG_Teams
	     WHERE league_key = @league_key AND season_key = @year AND team_slug = @teamSlug

        -- use earliest team_key for earlier years
    	IF (@team_key IS NULL)
	    BEGIN
            SELECT TOP 1 @team_key = team_key
              FROM dbo.SMG_Teams
    	     WHERE league_key = @league_key AND team_slug = @teamSlug
	         ORDER BY season_key ASC
	    END

        INSERT INTO @salaries (player_slug, team_key, salary_money, years, total_money, annual_money, position, name)
	    SELECT player_key, team_key, salary, CAST(contract_years AS VARCHAR(2)) + ' (' + contract_range + ')', contract_amount,
			   ROUND(salary_average, 0), override_position, override_firstname + ' ' + override_lastname
	      FROM SportsEditDB.dbo.SMG_Salaries
	     WHERE league_key = @league_key AND season_key = @year AND team_key = @teamSlug AND player_key <> 'team' AND ISNULL([status], '') <> 'CUT' AND salary > 0
    END

    --- POSITION FILTERING
	IF (@leagueName = 'mlb')
	BEGIN
		-- Filter out the salaries based on position
		IF (UPPER(@position) = 'IF')
		BEGIN
			DELETE @salaries
			 WHERE UPPER(position) NOT IN ('1B', '2B', 'SS', '3B')
		END
		ELSE IF (UPPER(@position) = 'OF')
		BEGIN
			DELETE @salaries
			 WHERE UPPER(position) NOT IN ('LF', 'CF', 'RF', 'OF')
		END
		ELSE IF (UPPER(@position) = 'P')
		BEGIN
			DELETE @salaries
			 WHERE UPPER(position) NOT IN ('P', 'SP', 'RP')
		END
		ELSE IF (LOWER(@position) <> 'all')
		BEGIN
			DELETE @salaries
			 WHERE UPPER(position) <> UPPER(@position)
		END
	END
	ELSE IF (@leagueName = 'nhl')
	BEGIN
		-- Filter out the salaries based on position
		IF (UPPER(@position) = 'F')
		BEGIN
			DELETE @salaries
			 WHERE UPPER(position) NOT IN ('C', 'LW', 'RW')
		END
		ELSE IF (LOWER(@position) <> 'all')
		BEGIN
			DELETE @salaries
			 WHERE UPPER(position) <> UPPER(@position)
		END
	END

    -- team
    DECLARE @team_season INT
    
    SELECT TOP 1 @team_season = season_key
	  FROM dbo.SMG_Teams
	 WHERE league_key = @league_key AND season_key >= @year
	 ORDER BY season_key ASC
	  
	UPDATE s
	   SET s.team_abbr = t.team_abbreviation, s.team_key = t.team_key,
	       s.team_link = 'http://www.usatoday.com/sports/' + @leagueName + '/' + t.team_slug + '/'
	  FROM @salaries AS s
	 INNER JOIN dbo.SMG_Teams AS t
		ON t.league_key = @league_key AND t.season_key = @team_season AND t.team_slug = s.team_key

    -- display
    UPDATE @salaries
       SET salary = '$' + REPLACE(CONVERT(VARCHAR, salary_money, 1), '.00', ''),
       	   total = '$' + REPLACE(CONVERT(VARCHAR, total_money, 1), '.00', ''),
       	   annual = '$' + REPLACE(CONVERT(VARCHAR, annual_money, 1), '.00', '')


    -- spotlight
    DECLARE @head_shot VARCHAR(100)
    DECLARE @name_position VARCHAR(100)
    DECLARE @contract_term VARCHAR(100)
    DECLARE @season_stats VARCHAR(100)
    DECLARE @team_logo VARCHAR(100)
    -- extra
    DECLARE @player_key VARCHAR(100)

	-- headshot
	SELECT @head_shot = head_shot + '120x120/' + [filename], @player_key = p.player_key
	  FROM @salaries AS s
	 INNER JOIN dbo.SMG_Players AS p
		ON s.player_slug = CASE WHEN p.date_of_birth IS NULL THEN SportsEditDB.dbo.SMG_fnSlugifyName(p.first_name + ' ' + p.last_name)
								ELSE SportsEditDB.dbo.SMG_fnSlugifyName(p.first_name + ' ' + p.last_name + ' ' + LEFT(p.date_of_birth, 4))
								END
	 INNER JOIN dbo.SMG_Rosters AS r ON r.player_key = p.player_key AND r.team_key = s.team_key
     WHERE r.season_key = @year AND r.team_key = @team_key AND
           head_shot IS NOT NULL AND [filename] IS NOT NULL

	SELECT TOP 1 @team_key = team_key, @name_position = name + ' - ' + position, @position = position,
		   @contract_term = years + '$' + REPLACE(CONVERT(VARCHAR, total_money, 1), '.00', ''),
           @team_logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/' + @leagueName + '-whitebg/220/' + team_abbr + '.png'	       
	  FROM @salaries
	 ORDER BY salary_money DESC
    		
    -- stats
	DECLARE @stats TABLE
	(
	    [column] VARCHAR(100),
	    value VARCHAR(100)
	)

	IF (@leagueName = 'mlb')
	BEGIN
		IF (@position = 'P')
		BEGIN
		    INSERT INTO @stats ([column], value)		    
		    SELECT [column], [value]
			  FROM SportsEditDB.dbo.SMG_Statistics
             WHERE season_key = @year AND sub_season_type = 'season-regular' AND player_key = @player_key AND [column] IN ('wins', 'era', 'pitching-strikeouts')
						   	
			SELECT @season_stats = CAST(@year AS VARCHAR) + ' Statistics: ' + wins + ' wins, ' + era + ' era, ' + [pitching-strikeouts] + ' strikeouts'
			  FROM @stats s
			 PIVOT (MAX(s.[value]) FOR s.[column] IN (wins, era, [pitching-strikeouts])) AS p
		END
		ELSE
		BEGIN
		    INSERT INTO @stats ([column], value)		    
		    SELECT [column], [value]
			  FROM SportsEditDB.dbo.SMG_Statistics
             WHERE season_key = @year AND sub_season_type = 'season-regular' AND player_key = @player_key AND [column] IN ('average', 'rbi', 'home-runs')

			SELECT @season_stats = CAST(@year AS VARCHAR) + ' Statistics: ' + average + ' avg, ' + rbi + ' rbi, ' + [home-runs] + ' hr'
			  FROM @stats s
			 PIVOT (MAX(s.[value]) FOR s.[column] IN (average, rbi, [home-runs])) AS p
		END
	END
	ELSE IF (@leagueName = 'nhl')
	BEGIN
		IF (@position = 'G')
		BEGIN
		    INSERT INTO @stats ([column], value)		    
		    SELECT [column], [value]
			  FROM SportsEditDB.dbo.SMG_Statistics
             WHERE season_key = @year AND sub_season_type = 'season-regular' AND player_key = @player_key AND [column] IN ('goaltender-wins', 'goals-against-average', 'save-percentage')

			SELECT @season_stats = CAST(@year AS VARCHAR) + ' Statistics: ' + [goaltender-wins] + ' wins, ' + [goals-against-average] + ' gaa, ' + [save-percentage] + ' sv pct'
			  FROM @stats s
			 PIVOT (MAX(s.[value]) FOR s.[column] IN ([goaltender-wins], [goals-against-average], [save-percentage])) AS p
		END
		ELSE
		BEGIN
		    INSERT INTO @stats ([column], value)		    
		    SELECT [column], [value]
			  FROM SportsEditDB.dbo.SMG_Statistics
             WHERE season_key = @year AND sub_season_type = 'season-regular' AND player_key = @player_key AND [column] IN ('goals', 'assists', 'penalty-minutes')

			SELECT @season_stats = CAST(@year AS VARCHAR) + ' Statistics: ' + goals + ' goals, ' + assists + ' assists, ' + [penalty-minutes] + ' pim'
			  FROM @stats s
			 PIVOT (MAX(s.[value]) FOR s.[column] IN (goals, assists, [penalty-minutes])) AS p
		END
	END

    -- notes
    DECLARE @notes VARCHAR(MAX)
    
    SELECT @notes = [value]
	  FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
     WHERE league_name = @leagueName AND page_id = 'salaries'


	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT @notes AS notes,
	(
		SELECT @head_shot AS head_shot, @team_logo AS logo, @name_position AS name_position,
		       @contract_term AS contract_term, @season_stats AS season_stats
		FOR XML RAW('spotlight'), TYPE
	),
	(
		SELECT 'Top Player Salary' AS ribbon,
		(
			SELECT 'true' AS 'json:Array',
			       team_key, player_slug AS player_id,
			       name, team_abbr, team_link, position, salary, years, total, annual
			  FROM @salaries
			 ORDER BY salary_money DESC, total_money DESC, name ASC
			   FOR XML RAW('row'), TYPE
		),
		(
			SELECT display, [column]
			  FROM @columns
			   FOR XML RAW('column'), TYPE
		)
		FOR XML RAW('table'), TYPE
	)
	FOR XML PATH(''), ROOT('root')

END

GO
