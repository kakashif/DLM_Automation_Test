USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnGetTeamRecords]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[SMG_fnGetTeamRecords] (
	@leagueKey VARCHAR(100),	
	@seasonKey INT,
	@teamKey VARCHAR(100),
	@dateTimeEST DATETIME
)
RETURNS VARCHAR(100)
AS
-- =============================================
-- Description:	return status of game
-- Update:	03/31/2014 - John Lin - remove parentheses to team record
--			04/24/2014 - Johh Lin - start of season null set to zero
--			10/29/2014 - ikenticus - adding EPL/Champions to MLS logic
--			02/18/2015 - ikenticus - soccer logic switched to W-T-L
--			02/24/2015 - ikenticus - fixing accidentally included NHL in the soccer logic swap
--			05/15/2015 - ikenticus - removing xmlteam l.league_key dependency
--			06/15/2015 - ikenticus - STATS INC team records match the exact start_date_time
-- =============================================
BEGIN
    DECLARE @wins INT
    DECLARE @losses INT
    DECLARE @ties INT
    DECLARE @date_time_EST DATETIME
    
/* DEPRECATED

    SELECT TOP 1 @wins = wins, @losses = losses, @ties = ties, @date_time_EST = date_time_EST
      FROM SportsEditDB.dbo.SMG_Team_Records
     WHERE season_key = @seasonKey AND team_key = @teamKey
     ORDER BY date_time_EST DESC

    IF (@date_time_EST > @dateTimeEST)
    BEGIN
        SELECT TOP 1 @wins = wins, @losses = losses, @ties = ties, @date_time_EST = date_time_EST
          FROM SportsEditDB.dbo.SMG_Team_Records
         WHERE season_key = @seasonKey AND team_key = @teamKey AND date_time_EST >= @dateTimeEST
         ORDER BY date_time_EST ASC
    END    

    -- start of season
    IF (@wins IS NULL OR @losses IS NULL OR @ties IS NULL)
    BEGIN
        SET @wins = 0
        SET @losses = 0
        SET @ties = 0
    END

	DECLARE @league_name VARCHAR(100)

	SELECT @league_name = value_to
	  FROM SportsDB.dbo.SMG_Mappings
	 WHERE value_type = 'league' AND value_from = @leagueKey
    
	IF (@league_name IN ('mls', 'epl', 'champions', 'natl', 'wwc'))
	BEGIN
	    RETURN CAST(@wins AS VARCHAR) + '-' + CAST(@ties AS VARCHAR) + '-' + CAST(@losses AS VARCHAR) 
	END

	IF (@league_name = 'nhl' OR (@league_name = 'nfl' AND @ties > 0))
	BEGIN
	    RETURN CAST(@wins AS VARCHAR) + '-' + CAST(@losses AS VARCHAR) + '-' + CAST(@ties AS VARCHAR)
	END
	
	RETURN CAST(@wins AS VARCHAR) + '-' + CAST(@losses AS VARCHAR)
*/
return ''
	
END

GO
