USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnGetMatchupEventKeyByLeagueAndTeam]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[SMG_fnGetMatchupEventKeyByLeagueAndTeam] (	
	@leagueName VARCHAR(100),
	@teamKey VARCHAR(100)
)
RETURNS VARCHAR(100)
AS
-- =============================================
-- Author:		Prashant Kamat
-- Create date: 1/31/2015
-- Description:	return default match up event key 
-- Update:	    02/23/2015 - pkamat: Fix NCAAF events
--				03/10/2015 - pkamat: Fix NCAAF events for new season
--				05/28/2015 - pkamat: Fix NBA events for post-season, NFL events for pre-season
-- =============================================
BEGIN

	DECLARE @event_key VARCHAR(100) = NULL;

    DECLARE @league_key VARCHAR(100), @season_key INT, @sub_season_type VARCHAR(100), @week VARCHAR(100);
    DECLARE @start_date DATETIME, @end_date DATETIME;

	SELECT @league_key = league_display_name
	  FROM dbo.USAT_leagues WITH (NOLOCK)
     WHERE league_name = LOWER(@leagueName);

    SELECT @season_key = season_key,
           @sub_season_type = sub_season_type,
           @week = [week],
           @start_date = [start_date]
      FROM dbo.SMG_Default_Dates WITH (NOLOCK)
     WHERE league_key = @leagueName AND page = 'scores';

    IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN     
        IF (@week = 'hall-of-fame')
        BEGIN
            SELECT @start_date = CONVERT(DATE, start_date_time_EST)
			  FROM dbo.SMG_Schedules WITH (NOLOCK)
			 WHERE league_key = 'l.nfl.com'
			   AND season_key = @season_key 
			   AND [week] = 'hall-of-fame';

            SELECT @end_date = DATEADD(SECOND, -1, DATEADD(DAY, 1, @start_date));    
        END
        ELSE IF (@week = 'bowls')
        BEGIN
			SELECT TOP 1 @start_date = CONVERT(DATE, start_date_time_EST)
			  FROM dbo.SMG_Schedules WITH (NOLOCK)
			 WHERE league_key = 'l.ncaa.org.mfoot'
			   AND season_key = @season_key
			   AND [week] = 'bowls'
			 ORDER BY start_date_time_EST;

			SELECT TOP 1 @end_date = CONVERT(DATE, start_date_time_EST)
			  FROM dbo.SMG_Schedules WITH (NOLOCK)
			 WHERE league_key = 'l.ncaa.org.mfoot'
			   AND season_key = @season_key
			   AND [week] = 'bowls'
			 ORDER BY start_date_time_EST DESC;

            SELECT @end_date = DATEADD(SECOND, -1, DATEADD(DAY, 1, @end_date));
        END
        ELSE
        BEGIN
            DECLARE @week_int INT = 0;

            IF (@leagueName = 'nfl')
            BEGIN
                DECLARE @fame_event_key VARCHAR(100);
            
				SELECT @fame_event_key = event_key
				  FROM dbo.SMG_Schedules WITH (NOLOCK)
				 WHERE league_key = @league_key 
				   AND season_key = @season_key 
				   AND [week] = 'hall-of-fame';

				IF (@fame_event_key IS NULL)
				BEGIN
					SELECT TOP 1 @start_date = CONVERT(DATE, start_date_time_EST)
					  FROM dbo.SMG_Schedules WITH (NOLOCK)
					 WHERE league_key = @league_key
					   AND season_key = @season_key
					   AND sub_season_type = @sub_season_type
					   AND [week] = @week
					 ORDER BY start_date_time_EST;
				END
				ELSE
				BEGIN
					SELECT TOP 1 @start_date = CONVERT(DATE, start_date_time_EST)
					  FROM dbo.SMG_Schedules WITH (NOLOCK)
					 WHERE league_key = @league_key
					   AND season_key = @season_key
					   AND sub_season_type = @sub_season_type
					   AND event_key <> @fame_event_key
					 ORDER BY start_date_time_EST;
				END

				IF (@sub_season_type = 'pre-season')
				BEGIN
					SELECT @week_int = CASE @week WHEN 'hall-of-fame' THEN 1 ELSE CAST(@week AS INT) END;
				END
				ELSE IF (@sub_season_type = 'season-regular')
				BEGIN
					SELECT @week_int = CAST(@week AS INT);
				END
				ELSE IF (@sub_season_type = 'post-season')
				BEGIN
					SELECT @week_int = CASE @week WHEN 'wild-card' THEN 1 WHEN 'divisional' THEN 2 WHEN 'conference' THEN 3 WHEN 'pro-bowl' THEN 4  WHEN 'super-bowl' THEN 5 END;
				END

				IF (@week_int >= 1)
				BEGIN
					SELECT @start_date = DATEADD(WEEK, @week_int - 1 , @start_date);
				END
            END
            ELSE
            BEGIN
				--Check for periods between seasons, get season key from stats
				SELECT TOP 1 @start_date = CONVERT(DATE, start_date_time_EST)
				  FROM dbo.SMG_Schedules WITH (NOLOCK)
				 WHERE league_key = @league_key
				   AND season_key = @season_key
				   AND [week] = @week
				 ORDER BY start_date_time_EST;

				IF (@start_date IS NULL)
				BEGIN
					SELECT @season_key = season_key
					  FROM dbo.SMG_Default_Dates WITH (NOLOCK)
					 WHERE league_key = @leagueName AND page = 'statistics';

					SELECT TOP 1 @start_date = CONVERT(DATE, start_date_time_EST)
					  FROM dbo.SMG_Schedules WITH (NOLOCK)
					 WHERE league_key = @league_key
					   AND season_key = @season_key
					 ORDER BY start_date_time_EST DESC;
				END
            END
            
            SELECT @end_date = DATEADD(SECOND, -1, DATEADD(WEEK, 1, @start_date));
        END
        
        -- team event for this week range
		SELECT @event_key = event_key
		  FROM dbo.SMG_Schedules WITH (NOLOCK)
		 WHERE (home_team_key = @teamKey OR away_team_key = @teamKey) AND start_date_time_EST BETWEEN @start_date AND @end_date;

        IF (@event_key IS NULL)
        BEGIN
            -- if no team event in range, return last team event
			SELECT TOP 1 @event_key = event_key
			  FROM dbo.SMG_Schedules WITH (NOLOCK)
			 WHERE (home_team_key = @teamKey OR away_team_key = @teamKey) AND start_date_time_EST < @start_date
			 ORDER BY start_date_time_EST DESC;
        END
    END
    ELSE
    BEGIN
        SELECT @end_date = DATEADD(SECOND, -1, DATEADD(DAY, 1, @start_date))

        -- team event for this range
        SELECT @event_key = event_key
          FROM dbo.SMG_Schedules WITH (NOLOCK)
         WHERE (home_team_key = @teamKey OR away_team_key = @teamKey) AND start_date_time_EST BETWEEN @start_date AND @end_date;

        IF (@event_key IS NULL)
        BEGIN
            -- get future team event in sub season
            SELECT TOP 1 @event_key = event_key
              FROM dbo.SMG_Schedules WITH (NOLOCK)
             WHERE (home_team_key = @teamKey OR away_team_key = @teamKey) AND start_date_time_EST > @end_date
             ORDER BY start_date_time_EST ASC;

            IF (@event_key IS NULL)
            BEGIN
                -- if no team event in range, return last team event
                SELECT TOP 1 @event_key = event_key
                  FROM dbo.SMG_Schedules WITH (NOLOCK)
                 WHERE (home_team_key = @teamKey OR away_team_key = @teamKey) AND start_date_time_EST < @start_date
                 ORDER BY start_date_time_EST DESC;
            END
        END
    END        

	RETURN @event_key
END

GO
