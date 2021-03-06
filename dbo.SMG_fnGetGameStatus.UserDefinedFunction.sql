USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnGetGameStatus]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[SMG_fnGetGameStatus] (	
	@leagueKey VARCHAR(100),
	@sub_season_type VARCHAR(100),
	@event_status VARCHAR(100),
	@period VARCHAR(100),
	@time_remaining VARCHAR(100)
)
RETURNS VARCHAR(100)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 12/30/2013
-- Description:	return status of game 
-- Update: 04/21/2014 - John Lin - cast period as integer before compare
--         09/25/2014 - John Lin - update NHL logic
--         11/08/2014 - ikenticus - update NBA intermission logic for OT
--         11/13/2014 - ikenticus - combined NFL/NCAAF & NBA/WNBA (4 periods), MLS & NCAAB/NCAAW (2 periods)
--         11/14/2014 - ikenticus - adding EPL/Champions to the 2 periods block
--         11/21/2014 - ikenticus - updating intermission logic to include zero time_remaining
--         12/08/2014 - ikenticus - separating soccer from basketball 2 periods block
--         01/07/2015 - ikenticus - adding ordinal to 1st/2nd NHL intermission
--         04/22/2015 - John Lin - fix NHL post season display
--         05/14/2015 - ikenticus - converting to league_name to support multiple sources
--         05/21/2015 - ikenticus - soccer should show ET when extra time, and FT for full time otherwise
--         08/15/2015 - John Lin - remove hour from time remaining for football
-- =============================================
BEGIN
    DECLARE @status VARCHAR(100) = ''

	DECLARE @suffix VARCHAR(50)
	SET @suffix = (CASE
	                  WHEN @period = '1' THEN 'st'
					  WHEN @period = '2' THEN 'nd'
					  WHEN @period = '3' THEN 'rd'
					  ELSE 'th'
				   END)


	DECLARE @league_name VARCHAR(100)

	SELECT @league_name = value_to
	  FROM SportsDB.dbo.SMG_Mappings
	 WHERE value_type = 'league' AND value_from = @leagueKey


	-- 1 Innings
	IF (@league_name = 'mlb')
	BEGIN
		IF (@event_status = 'post-event')
		BEGIN
			SET @status = (CASE
			                  WHEN CAST(@period AS INT) > 9 THEN 'Final ' + @period
			                  ELSE 'Final'
			              END)
		END
		ELSE
		BEGIN
			DECLARE @abbr VARCHAR(100)
			SET @abbr = (CASE
			                WHEN @time_remaining = 'bottom' THEN 'Bot'
			                ELSE 'Top'
			            END)
			
		    SET @status = (CASE
		                      WHEN @period = '0' THEN @abbr  + ' 1st'			
			                  ELSE @abbr + ' ' + @period + @suffix
			              END)
		END
	END

	-- 2 periods: basketball
    ELSE IF (@league_name IN ('ncaab', 'ncaaw'))
	BEGIN
	    IF (@event_status = 'post-event')
	    BEGIN
			SET @status = (CASE
			                  WHEN @period = '3' THEN 'Final OT'
							  WHEN CAST(@period AS INT) > 3 THEN 'Final ' + CAST((@period - 2) AS VARCHAR) + 'OT'
							  ELSE 'Final'
						  END)
	    END
	    ELSE IF (@event_status = 'intermission' OR @time_remaining IN ('0', '0:00'))
	    BEGIN
			SET @status = (CASE
						      WHEN @period = '3' THEN 'End OT'
						      WHEN CAST(@period AS INT) > 3 THEN 'End ' + CAST((CAST(@period AS INT) - 2) AS VARCHAR) + 'OT'
						      WHEN @period = '2' THEN 'End ' + @period + @suffix
						      ELSE 'Halftime'      
						  END)
	    END
	    ELSE
	    BEGIN
			SET @status = (CASE
			                  WHEN @period = '0' THEN '1st 20:00'
							  WHEN @period = '3' THEN 'OT ' + @time_remaining
							  WHEN CAST(@period AS INT) > 3 THEN CAST((CAST(@period AS INT) - 2) AS VARCHAR) + 'OT ' + @time_remaining
							  ELSE @period + @suffix + ' ' + @time_remaining
						  END)
	    END
	END

	-- 2 periods: soccer
    ELSE IF (@league_name IN ('mls', 'champions', 'epl', 'natl', 'wwc'))
	BEGIN
	    IF (@event_status = 'post-event')
	    BEGIN
			IF (@period > 2)
			BEGIN
				SET @status = 'ET'
			END
			ELSE
			BEGIN
				SET @status = 'FT'
			END
	    END
	    ELSE IF (@event_status = 'intermission' OR @time_remaining IN ('0', '0:00'))
	    BEGIN
			SET @status = (CASE
						      WHEN @period = '3' THEN 'End ET'
						      WHEN CAST(@period AS INT) > 3 THEN 'End ' + CAST((CAST(@period AS INT) - 2) AS VARCHAR) + 'ET'
						      ELSE 'End ' + @period + @suffix 
						  END)
	    END
	    ELSE
	    BEGIN
			SET @status = @time_remaining	-- should show minutes elapsed
	    END
	END

	-- 3 periods
	ELSE IF (@league_name IN ('nhl'))
	BEGIN
		IF (@event_status = 'post-event')
		BEGIN
			SET @status = (CASE
			                  WHEN @period = '4' THEN 'Final OT'
							  WHEN CAST(@period AS INT) > 4 THEN (CASE
							                                         WHEN @sub_season_type <> 'post-season' THEN 'Final SO'
							                                         ELSE 'Final ' + CAST((CAST(@period AS INT) - 3) AS VARCHAR) + 'OT'
							                                     END)
							  ELSE 'Final'
						  END)
		END
	    ELSE IF (@event_status = 'intermission' OR @time_remaining IN ('0', '0:00'))
	    BEGIN
			SET @status = (CASE
			                  WHEN @period IN ('1', '2') THEN @period + @suffix + ' Intermission'
							  ELSE 'Intermission'
						  END)
	    END
		ELSE
		BEGIN
			SET @status = (CASE
			                  WHEN @period = '0' THEN '1st 20:00'
							  WHEN @period = '4' THEN 'OT ' + @time_remaining
							  WHEN CAST(@period AS INT) > 4 THEN (CASE
							                                         WHEN @sub_season_type <> 'post-season' THEN 'SO'
							                                         ELSE CAST((CAST(@period AS INT) - 3) AS VARCHAR) + 'OT ' + @time_remaining
							                                     END)
							  ELSE @period + @suffix + ' ' + @time_remaining
						  END)
		END
	END

	-- 4 periods
	ELSE IF (@league_name IN ('nfl', 'ncaaf', 'nba', 'wnba'))
	BEGIN
		IF (@event_status = 'post-event')
		BEGIN
			SET @status = (CASE
			                  WHEN @period = '5' THEN 'Final OT'
							  WHEN CAST(@period AS INT) > 5 THEN 'Final ' + CAST((CAST(@period AS INT) - 4) AS VARCHAR) + 'OT'
 							  ELSE 'Final'
 						  END)
		END
	    ELSE IF (@event_status = 'intermission' OR @time_remaining IN ('0', '0:00'))
	    BEGIN
			SET @status = (CASE
						      WHEN @period = '5' THEN 'End OT'
						      WHEN CAST(@period AS INT) > 5 THEN 'End ' + CAST((CAST(@period AS INT) - 4) AS VARCHAR) + 'OT'
						      WHEN @period = '1' OR CAST(@period AS INT) > 2 THEN 'End ' + @period + @suffix
						      ELSE 'Halftime'      
						  END)
	    END
		ELSE
		BEGIN
		    IF (LEN(@time_remaining) = 8)
		    BEGIN
		        SET @time_remaining = RIGHT(@time_remaining, 5)
		    END
		    
			SET @status = (CASE
	                          WHEN @period = '0' THEN (CASE
															WHEN @leagueKey = 'l.wnba.com' THEN '1st 10:00'
															WHEN @leagueKey = 'l.nba.com' THEN '1st 12:00'
															ELSE '1st 15:00'
														END)
							  WHEN @period = '5' THEN 'OT ' + @time_remaining
							  WHEN CAST(@period AS INT) > 5 THEN CAST((CAST(@period AS INT) - 4) AS VARCHAR) + 'OT ' + @time_remaining
							  ELSE @period + @suffix + ' ' + @time_remaining
						  END)
		END
	END	

	RETURN @status
	
END

GO
