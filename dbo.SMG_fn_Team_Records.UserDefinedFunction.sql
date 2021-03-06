USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fn_Team_Records]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[SMG_fn_Team_Records] (
	@leagueName VARCHAR(100),	
	@seasonKey INT,
	@teamKey VARCHAR(100),
	@eventKey VARCHAR(100)
)
RETURNS VARCHAR(100)
AS
-- =============================================
-- Description:	return status of game
-- Update: 07/09/2015 - John Lin - redesign via STATS migration
--         07/10/2015 - John Lin - specific date without event key
--         09/09/2015 - ikenticus - team_record should be the first one BEFORE specified date_time
--         09/10/2015 - ikenticus - add sub_season_start to correctly isolate subseason for team_record
--         10/05/2015 - John Lin - use regular for post season
--         10/12/2015 - John Lin - adjust end date time
--         10/16/2015 - ikenticus - excluding certain leagues from post->regular season hack, i.e. Champions League
-- =============================================
BEGIN
    DECLARE @league_key VARCHAR(100) = SportsDB.dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @wins INT
    DECLARE @losses INT
    DECLARE @ties INT

    DECLARE @date_time_EST DATETIME
    DECLARE @sub_season_type VARCHAR(100)
	DECLARE @sub_season_start DATETIME

    IF (ISDATE(@eventKey) =  1)
    BEGIN
        SET @date_time_EST = @eventKey

        SELECT TOP 1 @sub_season_type = sub_season_type
		  FROM dbo.SMG_Schedules
		 WHERE league_key = @league_key AND season_key = @seasonKey AND start_date_time_EST > @date_time_EST
		 ORDER BY start_date_time_EST ASC

        IF (@sub_season_type = 'post-season')
        BEGIN
            SET @sub_season_type = 'season-regular'
        END
        
		SELECT TOP 1 @sub_season_start = start_date_time_EST
		  FROM dbo.SMG_Schedules
		 WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @sub_season_type
		 ORDER BY start_date_time_EST ASC

        SELECT TOP 1 @wins = wins, @losses = losses, @ties = ties
          FROM dbo.SMG_Team_Records
         WHERE season_key = @seasonKey AND team_key = @teamKey AND start_date_time_EST BETWEEN @sub_season_start AND @date_time_EST
         ORDER BY start_date_time_EST DESC
    END
    ELSE
    BEGIN
        SELECT @wins = wins, @losses = losses, @ties = ties
          FROM dbo.SMG_Team_Records
         WHERE league_key = @league_key AND team_key = @teamKey AND event_key = @eventKey

  		SELECT @sub_season_type = sub_season_type, @date_time_EST = start_date_time_EST
    	  FROM dbo.SMG_Schedules
	     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @eventKey

        IF (@wins IS NULL OR @sub_season_type = 'post-season')
        BEGIN
            IF (@sub_season_type = 'post-season' AND @leagueName NOT IN ('champions'))
            BEGIN
                SET @sub_season_type = 'season-regular'

        		SELECT TOP 1 @date_time_EST = start_date_time_EST
	        	  FROM dbo.SMG_Schedules
		         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @sub_season_type
		         ORDER BY start_date_time_EST DESC
            END

    		SELECT TOP 1 @sub_season_start = start_date_time_EST
	    	  FROM dbo.SMG_Schedules
		     WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @sub_season_type
		     ORDER BY start_date_time_EST ASC

            SELECT TOP 1 @wins = wins, @losses = losses, @ties = ties
              FROM dbo.SMG_Team_Records
             WHERE season_key = @seasonKey AND team_key = @teamKey AND start_date_time_EST BETWEEN @sub_season_start AND @date_time_EST
             ORDER BY start_date_time_EST DESC
        END
    END


    -- start of season
    IF (@wins IS NULL)
    BEGIN
        SET @wins = 0
        SET @losses = 0
        SET @ties = 0
    END
  
	IF (@leagueName IN ('mls', 'epl', 'champions', 'natl', 'wwc'))
	BEGIN
	    RETURN CAST(@wins AS VARCHAR) + '-' + CAST(@ties AS VARCHAR) + '-' + CAST(@losses AS VARCHAR) 
	END

	IF (@leagueName = 'nhl' OR (@leagueName = 'nfl' AND @ties > 0))
	BEGIN
	    RETURN CAST(@wins AS VARCHAR) + '-' + CAST(@losses AS VARCHAR) + '-' + CAST(@ties AS VARCHAR)
	END
	
	RETURN CAST(@wins AS VARCHAR) + '-' + CAST(@losses AS VARCHAR)
	
END

GO
