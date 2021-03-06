USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAASalaries_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetNCAASalaries_XML]
    @sport VARCHAR(100),
	@position VARCHAR(100)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 02/14/2013
-- Description:	Get list of college staff salaries
-- Update: 03/22/2013 - John Lin - add credits
--         04/01/2013 - add head shot
--         04/02/2013 - max year should be sport and position
--         04/12/2013 - fix typo
--         08/07/2013 - John Lin - remove cdn host for head shot
--         11/05/2013 - John Lin - hard code 7 coaches to empty if 0
--         12/09/2013 - John Lin - add NCAAF assistant
--         04/22/2014 - John Lin - add year to ribbon
--         04/23/2014 - thlam - update the text for tag and ribbon
--         10/28/2014 - John Lin - add contract id
--         11/07/2014 - John Lin - add rgb
--         11/10/2014 - John Lin - abbr from SMG_Teams
--         11/14/2014 - John Lin - add have notes and N/A, @leagueName to @sport
--         12/10/2014 - John Lin - hard code 2 school football assistant staff pay
--         10/01/2015 - John Lin - last year bonus 
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_name VARCHAR(100)
	DECLARE @media_root VARCHAR(100) = 'SMG/'
    DECLARE @year INT;

    IF (@sport = 'mens-basketball')
    BEGIN
        SET @league_name = 'ncaab'
    END
    ELSE IF (@sport = 'football')
    BEGIN
        SET @league_name = 'ncaaf'
    END
    ELSE IF (@sport = 'womens-basketball')
    BEGIN
        SET @league_name = 'ncaaw'
    END
    
    IF (@position = 'director')
    BEGIN
        SELECT @year = MAX(fncs.year)
          FROM SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries fncs
         INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches fnc
            ON fnc.id = fncs.coach_id     
         WHERE fncs.position = @position
    END    
    ELSE
    BEGIN
        SELECT @year = MAX(fncs.year)
          FROM SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries fncs
         INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches fnc
            ON fnc.id = fncs.coach_id     
         WHERE fnc.sport = @league_name AND fncs.position = @position
    END

    DECLARE @salaries TABLE
    (
        coach_id INT,
        coach_first VARCHAR(100),
        coach_last VARCHAR(100),
        contract_id INT,
        school_id INT,
        school_name VARCHAR(100),
        sport VARCHAR(100),
        conference VARCHAR(100),
        school_pay INT,
        other_pay INT,
        total_pay INT,
        max_bonus INT,
        staff_pay INT,
        have_notes INT DEFAULT 0,
        last_year_bonus INT
    )

    INSERT INTO @salaries (coach_id, coach_first, coach_last, contract_id, school_id, school_name, sport, conference,
                           school_pay, other_pay, total_pay, max_bonus, staff_pay, last_year_bonus)
    SELECT fnc.id,
           fnc.first_name,
           fnc.last_name,
           fncs.contract_id,
           fns.id,
           fns.name,
           fnc.sport,
           fncs.conference,
           fncs.school_pay,
           fncs.other_pay,
           fncs.total_pay,
           fncs.max_bonus,
           fncs.staff_pay,
           fncs.last_year_bonus
      FROM SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries fncs
     INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches fnc
        ON fnc.id = fncs.coach_id
     INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Schools fns
        ON fns.id = fncs.school_id
     WHERE fncs.year = @year AND fncs.position = @position -- AND fncs.school_pay IS NOT NULL AND fncs.school_pay <> 0
        
    IF (@position <> 'director')
    BEGIN
        DELETE @salaries
         WHERE sport <> @league_name
    END
    
    -- spotlight
    DECLARE @coach_id INT
    DECLARE @coach_name VARCHAR(100)
    DECLARE @school_id INT       
    DECLARE @current_total INT
    DECLARE @previous_total INT
    DECLARE @delta VARCHAR(100)
    DECLARE @team_abbr VARCHAR(100)
    DECLARE @team_rgb VARCHAR(100)
    DECLARE @tag VARCHAR(100) 
    DECLARE @head_shot VARCHAR(100)
        
    SELECT TOP 1 @school_id = school_id, @coach_id = coach_id, @coach_name = coach_first + ' ' + coach_last, @current_total = total_pay
      FROM @salaries
     ORDER BY total_pay DESC
     
    SELECT TOP 1 @previous_total = total_pay
      FROM SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries
     WHERE year = (@year - 1) AND coach_id = @coach_id

    SELECT @head_shot = ISNULL(head_shot, '')
      FROM SportsEditDB.dbo.Feeds_NCAA_Coaches
     WHERE id = @coach_id
   
    IF (@head_shot <> '')
    BEGIN
       SELECT @head_shot = @media_root + @head_shot + '_l.jpg'
    END
      
    IF (@current_total > @previous_total)
    BEGIN
        SELECT @delta = '+' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, @current_total - @previous_total), 1), 2)
    END
    ELSE
    BEGIN
        SELECT @delta = '-' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, @previous_total - @current_total), 1), 2)
    END

    IF (@position = 'director')
    BEGIN
        SELECT @league_name = 'ncaaf'
        SELECT @tag = 'TOP ATHLETIC DIRECTOR PAY'
    END
    ELSE IF (@position = 'assistant')
    BEGIN
        IF (@league_name = 'ncaaf')
        BEGIN
            SELECT @tag = 'TOP NCAAF ASSISTANT COACH PAY'
        END
        ELSE
        BEGIN
            SELECT @tag = 'TOP NCAAB ASSISTANT COACH PAY'
        END      
    END
    ELSE
    BEGIN
        IF (@league_name = 'ncaaf')
        BEGIN
            SELECT @tag = 'TOP NCAAF COACH PAY'
        END
        ELSE
        BEGIN
            SELECT @tag = 'TOP NCAAB COACH PAY'
        END      
    END
        
    SELECT @team_abbr = st.team_abbreviation, @team_rgb = st.rgb
      FROM SportsEditDB.dbo.Feeds_NCAA_Schools_Mappings fnsm
     INNER JOIN SportsDB.dbo.SMG_Teams st
        ON st.season_key = @year AND st.team_key = fnsm.team_key
     WHERE fnsm.id = @school_id AND fnsm.sport = @league_name

    -- positions       
    DECLARE @positions TABLE 
    (
        sport VARCHAR(100),
        position VARCHAR(100), 
        ribbon VARCHAR(100),
        dropdown VARCHAR(100)
    )
    
    INSERT INTO @positions (sport, position, ribbon, dropdown)        
    VALUES ('football', 'coach', CAST(@year AS VARCHAR) + ' NCAAF Coaches Salaries', 'NCAAF Coaches'),
           ('football', 'assistant', CAST(@year AS VARCHAR) + ' NCAAF Assistant Coaches Salaries', 'NCAAF Assistant Coaches'),
           ('mens-basketball', 'coach', CAST(@year AS VARCHAR) + ' NCAAB TOURNAMENT COACHES'' PAY', 'NCAAB Coaches'),
           ('all', 'director', CAST(@year AS VARCHAR) + ' NCAA Athletic Directors Salaries', 'NCAA Athletic Directors')    
    
    UPDATE @salaries
       SET school_pay = NULL
     WHERE school_pay = 0 AND coach_id IN (1046, 173, 353, 69, 1042, 1889, 977)

    UPDATE @salaries
       SET total_pay = NULL
     WHERE total_pay = 0 AND coach_id IN (1046, 173, 353, 69, 1042, 1889, 977)

    UPDATE @salaries
       SET max_bonus = NULL
     WHERE max_bonus = 0 AND coach_id IN (1046, 173, 353, 69, 1042, 1889, 977)

    IF (@sport = 'football' AND @position = 'assistant')
    BEGIN
        UPDATE @salaries
           SET staff_pay = NULL
         WHERE school_id IN (223232, 207971)
    END
    
    UPDATE s
      SET have_notes = 1
     FROM @salaries s
    INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries fncs
       ON fncs.coach_id = s.coach_id AND fncs.[year] = @year
    INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Contract_Notes fncn
       ON fncs.contract_id = fncn.contract_id
    
                      
    SELECT
	(
        SELECT coach_id, coach_first, coach_last, contract_id, school_id, school_name, conference, have_notes,
               CASE
                   WHEN school_pay IS NULL THEN '--'
                   ELSE '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, school_pay), 1), 2)
               END AS school_pay,
               CASE 
                   WHEN other_pay IS NULL THEN '--'
                   ELSE '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, other_pay), 1), 2)
               END AS other_pay, 
               CASE 
                   WHEN total_pay IS NULL THEN '--'
                   ELSE '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, total_pay), 1), 2)
               END AS total_pay, 
               CASE 
                   WHEN max_bonus IS NULL THEN '--'
                   ELSE '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, max_bonus), 1), 2)
               END AS max_bonus, 
               CASE 
                   WHEN staff_pay IS NULL THEN '--'
                   ELSE '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, staff_pay), 1), 2)
               END AS staff_pay,
               CASE 
                   WHEN last_year_bonus IS NULL THEN '--'
                   ELSE '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, last_year_bonus), 1), 2)
               END AS last_year_bonus
          FROM @salaries AS s
         ORDER BY s.total_pay DESC
           FOR XML RAW('salaries'), TYPE
    ),
    (
        SELECT sport, position, ribbon, dropdown
          FROM @positions
           FOR XML RAW('positions'), TYPE
    ),
    (
       SELECT @year AS current_year,
              '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, @current_total), 1), 2) AS current_total,
              (@year - 1) AS previous_year,
              '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, @previous_total), 1), 2) AS previous_total,
              @delta AS delta,
              @coach_name AS coach_name,
              @team_abbr AS team_abbr,
              @team_rgb AS team_rgb,
              @tag AS tag,
              @head_shot AS head_shot,
              (SELECT credits
                 FROM SportsEditDB.dbo.Feeds_Credits
                WHERE [type] = 'salary-' + @position + '-' + @league_name) AS credits
          FOR XML RAW('spotlight'), TYPE
    )
    FOR XML PATH(''), ROOT('edits')

    SET NOCOUNT OFF;
END

GO
