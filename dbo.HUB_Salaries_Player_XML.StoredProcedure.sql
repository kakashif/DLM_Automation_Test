USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_Salaries_Player_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_Salaries_Player_XML]
	@leagueName	VARCHAR(100),
	@playerId	VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 01/08/2015
-- Description:	get Salaries History using new SMG_Salaries table
--				02/18/2015 - ikenticus: adding editorial overrides
-- Update:      04/01/2015 - John Lin - seperate player and team
--              04/02/2015 - John Lin - return row as list
--              04/07/2015 - John Lin - statistics using regular season
--              04/08/2015 - John Lin - new head shot logic
--              04/28/2015 - John Lin - modified player id to varchar
--				07/27/2015 - ikenticus - migrating to decoupled player/team keys
-- =============================================
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @league_key VARCHAR(100) = SportsDB.dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @embargo_season INT

	-- embargo latest season
	SELECT @embargo_season = season_key
	  FROM dbo.SMG_Default_Dates
	 WHERE league_key = @leagueName AND page = 'salaries'

	IF (@embargo_season IS NULL)
	BEGIN
		SET @embargo_season = YEAR(GETDATE())
	END

	-- TABLE definitions
	DECLARE @columns TABLE (
		display  VARCHAR(100),
		[column] VARCHAR(100)
	)
	INSERT INTO @columns (display, [column])
	VALUES ('Season', 'season_key'),  ('Team', 'team_abbr'), ('Position', 'position'), ('Salary', 'salary')

	DECLARE @salaries TABLE
	(
		season_key INT,
		team_abbr  VARCHAR(100),
		[position] VARCHAR(100),
		first_name VARCHAR(100),
		last_name VARCHAR(100),
		years VARCHAR(100),
		total_money MONEY,
		salary MONEY,
		-- extra
		team_key VARCHAR(100),
		team_slug VARCHAR(100)
	)
	INSERT INTO @salaries (season_key, salary, team_slug, [position], first_name, last_name, years, total_money)
	SELECT season_key, salary, team_key, override_position, override_firstname, override_lastname,
		   CAST(contract_years AS VARCHAR(2)) + ' (' + contract_range + ')', contract_amount
	  FROM SportsEditDB.dbo.SMG_Salaries
	 WHERE season_key <= @embargo_season AND player_key = @playerId

	-- teams
	UPDATE s
	   SET s.team_abbr = st.team_abbreviation, s.team_key = st.team_key
	  FROM @salaries s
	 INNER JOIN dbo.SMG_Teams st
		ON st.league_key = @league_key AND st.season_key >= s.season_key AND st.team_slug = s.team_slug


    -- spotlight
    DECLARE @head_shot VARCHAR(100)
    DECLARE @name_position VARCHAR(100)
    DECLARE @contract_term VARCHAR(100)
    DECLARE @season_stats VARCHAR(100)
    -- extra
    DECLARE @season_key VARCHAR(100)
    DECLARE @team_key VARCHAR(100)
    DECLARE @team_abbr VARCHAR(100)
    DECLARE @player_key VARCHAR(100)
    DECLARE @position VARCHAR(100)

	SELECT TOP 1 @season_key = season_key, @team_key = team_key, @team_abbr = team_abbr,
		   @name_position = first_name + ' ' + last_name + ' - ' + [position], @position = [position],
		   @contract_term = years + '$' + REPLACE(CONVERT(VARCHAR, total_money, 1), '.00', '')
	  FROM @salaries
	 ORDER BY season_key DESC

    -- team_logo
    DECLARE @team_logo VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/' + @leagueName + '-whitebg/220/' + @team_abbr + '.png'
    
	SELECT @head_shot = head_shot + '120x120/' + [filename], @player_key = p.player_key
	  FROM @salaries AS s
	 INNER JOIN dbo.SMG_Players AS p
		ON @playerId = CASE WHEN p.date_of_birth IS NULL THEN SportsEditDB.dbo.SMG_fnSlugifyName(p.first_name + ' ' + p.last_name)
							ELSE SportsEditDB.dbo.SMG_fnSlugifyName(p.first_name + ' ' + p.last_name + ' ' + LEFT(p.date_of_birth, 4))
							END
	 INNER JOIN dbo.SMG_Rosters AS r ON r.player_key = p.player_key AND r.team_key = s.team_key
     WHERE r.season_key = @season_key AND r.team_key = @team_key AND
           head_shot IS NOT NULL AND [filename] IS NOT NULL

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
             WHERE season_key = @season_key AND sub_season_type = 'season-regular' AND player_key = @player_key AND [column] IN ('wins', 'era', 'pitching-strikeouts')
						   	
			SELECT @season_stats = CAST(@season_key AS VARCHAR) + ' Statistics: ' + wins + ' wins, ' + era + ' era, ' + [pitching-strikeouts] + ' strikeouts'
			  FROM @stats s
			 PIVOT (MAX(s.[value]) FOR s.[column] IN (wins, era, [pitching-strikeouts])) AS p
		END
		ELSE
		BEGIN
		    INSERT INTO @stats ([column], value)		    
		    SELECT [column], [value]
			  FROM SportsEditDB.dbo.SMG_Statistics
             WHERE season_key = @season_key AND sub_season_type = 'season-regular' AND player_key = @player_key AND [column] IN ('average', 'rbi', 'home-runs')

			SELECT @season_stats = CAST(@season_key AS VARCHAR) + ' Statistics: ' + average + ' avg, ' + rbi + ' rbi, ' + [home-runs] + ' hr'
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
             WHERE season_key = @season_key AND sub_season_type = 'season-regular' AND player_key = @player_key AND [column] IN ('goaltender-wins', 'goals-against-average', 'save-percentage')

			SELECT @season_stats = CAST(@season_key AS VARCHAR) + ' Statistics: ' + [goaltender-wins] + ' wins, ' + [goals-against-average] + ' gaa, ' + [save-percentage] + ' sv pct'
			  FROM @stats s
			 PIVOT (MAX(s.[value]) FOR s.[column] IN ([goaltender-wins], [goals-against-average], [save-percentage])) AS p
		END
		ELSE
		BEGIN
		    INSERT INTO @stats ([column], value)		    
		    SELECT [column], [value]
			  FROM SportsEditDB.dbo.SMG_Statistics
             WHERE season_key = @season_key AND sub_season_type = 'season-regular' AND player_key = @player_key AND [column] IN ('goals', 'assists', 'penalty-minutes')

			SELECT @season_stats = CAST(@season_key AS VARCHAR) + ' Statistics: ' + goals + ' goals, ' + assists + ' assists, ' + [penalty-minutes] + ' pim'
			  FROM @stats s
			 PIVOT (MAX(s.[value]) FOR s.[column] IN (goals, assists, [penalty-minutes])) AS p
		END
	END



	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT
	(
		SELECT @head_shot AS head_shot, @team_abbr AS team_abbr, @team_logo AS logo, @name_position AS name_position,
		       @contract_term AS contract_term, @season_stats AS season_stats
		FOR XML RAW('spotlight'), TYPE
	),
	(
		SELECT
		(
			SELECT 'true' AS 'json:Array',
			       season_key, team_abbr, [position], '$' + REPLACE(CONVERT(VARCHAR, salary, 1), '.00', '') AS salary
			  FROM @salaries
			 ORDER BY season_key DESC
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
