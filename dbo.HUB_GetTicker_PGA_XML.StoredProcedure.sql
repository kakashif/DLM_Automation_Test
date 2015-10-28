USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetTicker_PGA_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[HUB_GetTicker_PGA_XML]
AS
--=============================================
-- Author:  John Lin
-- Create date: 02/12/2015
-- Description: get ticker
-- Update: 07/16/2015 - John Lin - override via SMG_Default_Dates
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @event_key VARCHAR(100)
    DECLARE @season_key INT
	    
    SELECT @season_key = season_key, @event_key = [week]
      FROM dbo.SMG_Default_Dates
     WHERE league_key = 'pga-tour' AND page = 'source'	     

    IF (@season_key IS NOT NULL AND @event_key IS NOT NULL)
    BEGIN
        EXEC dbo.DES_Suspender_Golf_XML @season_key, @event_key
        
        RETURN
    END


    DECLARE @tour_code VARCHAR(100) = 'R'
    DECLARE @format VARCHAR(100)
    DECLARE @tour_id INT

    DECLARE @link_head VARCHAR(100) = 'GOLF'
    DECLARE @link_text VARCHAR(100)
    DECLARE @link_href VARCHAR(100)
   
    DECLARE @fedex VARCHAR(100)
     -- Compare the PGA Tour to our own SMG_Solo_Events and display FedEx when tournament name is NULL
    DECLARE @current_tour VARCHAR(100)


    SELECT @tour_id = tour_id, @format = LOWER(format), @fedex = LOWER(fedex)
      FROM PGA_Current_Tour
     WHERE tour_code = @tour_code

    -- check format
    SELECT TOP 1 @current_tour = name
      FROM SMG_Solo_Events sse
      LEFT OUTER JOIN PGA_Tournaments pt
        ON pt.name = sse.event_name OR pt.loc = sse.site_name OR pt.local_city = sse.site_city
     WHERE sse.league_key = 'l.pga.com' AND sse.start_date_time <= GETDATE()
     ORDER BY sse.start_date_time DESC, pt.name DESC

    IF (@current_tour IS NULL)
    BEGIN
        SET @format = 'fedex'
    END
    ELSE
    BEGIN
        DECLARE @num_results INT
/*
08/07/2014: the num_results test did not work when they do NOT send the tournament info at all (i.e. PGA Championships)
         fall back to the leaderboard @num_results logic only after @current_tour IS NOT NULL
*/
        SELECT @num_results = COUNT(*)
          FROM PGA_Leaderboard
         WHERE tour_id = @tour_id AND tour_code = @tour_code AND ISNUMERIC(tourn_par_rel) = 1

        IF (@num_results = 0 AND @fedex = 'yes')
        BEGIN
            SET @format = 'fedex'
        END
    END


    IF (@format = 'fedex')
    BEGIN
        SET @link_text = 'Full Standings'
        SET @link_href = 'http://www.pgatour.com/stats/stat.02671.html/?cid=USAT_fullFEC'
    END
    ELSE
    BEGIN
        SET @link_text = 'Full Leaderboard'
        SET @link_href = 'http://www.pgatour.com/leaderboard.html/?cid=USAT_top5LB'
    END


    IF (@format IN ('stroke', 'stroke-play', 'stableford', 'modified-stableford'))
    BEGIN
        SELECT
        (
            SELECT TOP 1 'Round ' + cur_rnd AS [round], local_city + ', ' + loc_state AS location, name, @format AS format
              FROM PGA_Tournaments 
             WHERE id = @tour_id
               FOR XML RAW ('tour'), TYPE
        ),
        (
            SELECT cur_pos + ' ' + fname + ' ' + lname AS player, cur_par_rel + ' | ' + thru + ' | ' + tourn_par_rel AS outcome, sort
              FROM PGA_Leaderboard 
             WHERE cur_pos IN (SELECT TOP 5 cur_pos AS sort 
                                 FROM PGA_Leaderboard 
                                WHERE tour_id = @tour_id AND tour_code = @tour_code
                                GROUP BY cur_pos, sort ORDER BY CONVERT(INT, sort) -- display Top 5th ranks
                              ) AND tour_id = @tour_id AND tour_code = @tour_code ORDER BY sort 
               FOR XML RAW ('players'), TYPE
        ),
        (
            SELECT '_blank' AS link_target, @link_head AS link_head, @link_text AS link_text, @link_href AS link_href
               FOR XML RAW('link'), TYPE
        )
        FOR XML PATH (''), ROOT ('root')
    END
    ELSE IF (@format IN ('match', 'match-play'))
    BEGIN
        -- Match Play
        DECLARE @leaderboard TABLE
        (
            id INT IDENTITY(1,1) PRIMARY KEY,
            fname VARCHAR(200),
            lname VARCHAR(200),
            tourn_par_rel VARCHAR(32),
            sort INT
        )
        DECLARE @match_leaderboard TABLE
        (
            id INT IDENTITY(1,1) PRIMARY KEY,
            fname1 VARCHAR(200),
            lname1 VARCHAR(200),
            fname2 VARCHAR(200),
            lname2 VARCHAR(200),
            seed1 VARCHAR(10),
            seed2 VARCHAR(10),
            diff INT,
            sort INT
        )
        DECLARE @i INT
        DECLARE @j INT
        DECLARE @max_id INT

        DECLARE @fname1 VARCHAR(200)
        DECLARE @lname1 VARCHAR(200)
        DECLARE @fname2 VARCHAR(200)
        DECLARE @lname2 VARCHAR(200)
        DECLARE @tourn_par_rel1 VARCHAR(32)
        DECLARE @tourn_par_rel2 VARCHAR(32)

        DECLARE @tpr1 INT
        DECLARE @tpr2 INT

        DECLARE @sort INT
        DECLARE @diff INT

        INSERT INTO @leaderboard
        SELECT TOP 10 fname, lname, tourn_par_rel, sort
          FROM PGA_Leaderboard 
         WHERE tour_id = @tour_id AND tour_code = @tour_code
         ORDER BY sort 

        SET @i = 1
        SELECT @max_id = MAX(id)
          FROM @leaderboard

        WHILE @i <= @max_id
        BEGIN
            SET @j = @i + 1

            SELECT @fname1 = fname, @lname1 = lname, @tourn_par_rel1 = tourn_par_rel, @sort = sort
              FROM @leaderboard
             WHERE id = @i
            
            SELECT @fname2 = fname, @lname2 = lname, @tourn_par_rel2 = tourn_par_rel
              FROM @leaderboard
             WHERE id = @j

            BEGIN TRY
                SET @tpr1 = CAST(@tourn_par_rel1 as INT)
                SET @tpr2 = CAST(@tourn_par_rel2 as INT)

                IF (@tpr1 <= @tpr2)
                BEGIN
                    SET @diff = @tpr2 - @tpr1
                    
                    INSERT INTO @match_leaderboard (fname1, lname1, fname2, lname2, diff, sort, seed1, seed2)
                    VALUES (@fname1, @lname1, @fname2, @lname2, @diff, @sort, '', '')
                END
                ELSE
                BEGIN
                    INSERT INTO @match_leaderboard (fname1, lname1, fname2, lname2, diff, sort, seed1, seed2)
                    VALUES (@fname2, @lname2, @fname1, @lname1, @diff, @sort, '', '')
                    
                    SET @diff = @tpr1 - @tpr2
                END
            END TRY
            BEGIN CATCH
                SET @diff = 0
                INSERT INTO @match_leaderboard (fname1, lname1, fname2, lname2, diff, sort, seed1, seed2) VALUES (@fname1, @lname1, @fname2, @lname2, @diff, @sort, '', '')
            END CATCH

            SET @i = @i + 2
        END

        SELECT
        (
            SELECT TOP 1 'Round ' + cur_rnd AS [round], local_city + ', ' + loc_state as location, name, @format as format
              FROM PGA_Tournaments 
             WHERE id = @tour_id
               FOR XML RAW ('tour'), TYPE
        ),
        (
            SELECT (seed1 + ' ' + SUBSTRING(fname1, 1, 1) + ' ' + lname1) AS player1,
                   (seed2 + ' ' + SUBSTRING(fname2, 1, 1) + ' ' + lname2) AS player2,
                   (lname1 + ' ' + CAST(diff AS VARCHAR) + ' UP') AS outcome,
                   sort
              FROM @match_leaderboard
             ORDER BY sort
               FOR XML RAW ('players'), TYPE
        ),
        (
            SELECT '_blank' AS link_target, @link_head AS link_head, @link_text AS link_text, @link_href AS link_href
               FOR XML RAW('link'), TYPE
        )
        FOR XML PATH (''), ROOT ('root')
    END
    ELSE IF (@format = 'fedex')
    BEGIN
        -- FedEx ranking
        SELECT 
        (
            SELECT TOP 1 'FedExCup Top 5' as [round], @format as format
              FROM PGA_Tournaments 
             WHERE id = @tour_id
               FOR XML RAW ('tour'), TYPE
        ),
        (
            SELECT CAST(pos AS VARCHAR) + ' ' + name as player, points, pos
              FROM PGA_Fedex_Ranking
             ORDER BY pos
               FOR XML RAW ('players'), TYPE
        ),
        (
            SELECT '_blank' AS link_target, @link_head AS link_head, @link_text AS link_text, @link_href AS link_href
               FOR XML RAW('link'), TYPE
        )
        FOR XML PATH (''), ROOT ('root')
    END
                
    SET NOCOUNT OFF 
END


GO
