USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetProfile_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetProfile_XML]
    @guid VARCHAR(100)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 01/26/2015
-- Description:	get profile
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @brackets TABLE 
	(
        bracket_key VARCHAR(100),
        name VARCHAR(100),
        points_earned VARCHAR(100),
        points_total VARCHAR(100),
        picks_correct VARCHAR(100),
        picks_total VARCHAR(100),
        points_remaining VARCHAR(100),
        winner_abbr VARCHAR(100),
        -- extra
        league_name VARCHAR(100),
        season_key INT
	)
    DECLARE @pools TABLE 
	(
        pool_key     VARCHAR(100),
        bracket_key  VARCHAR(100),
        [name]       VARCHAR(100),
        participants INT,
        [rank]       VARCHAR(100),
        editable     INT
	)

    INSERT INTO @brackets(bracket_key, name, points_earned, picks_correct, points_remaining, winner_abbr, league_name, season_key)
    SELECT bracket_key, name, points_earned, picks_correct, points_remaining, winner_abbr, league_name, season_key
      FROM dbo.UGC_Bracket_Names
     WHERE [guid] = @guid

	-- pool
    INSERT INTO @pools (pool_key, editable)
    SELECT pool_key, 0
      FROM dbo.UGC_Pools
     WHERE [guid] = @guid


    IF NOT EXISTS (SELECT 1 FROM @brackets)
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM @pools)
        BEGIN
            SELECT '' AS [profile]
               FOR XML PATH(''), ROOT('root')

            RETURN
        END
    END



    UPDATE b
       SET b.picks_total = n.number
      FROM @brackets b
     INNER JOIN dbo.UGC_GUID_Names n
        ON n.[first] = b.league_name AND n.[last] = CAST(b.season_key AS VARCHAR) AND n.[guid] = 'picks'

    UPDATE b
       SET b.points_total = n.number
      FROM @brackets b
     INNER JOIN dbo.UGC_GUID_Names n
        ON n.[first] = b.league_name AND n.[last] = CAST(b.season_key AS VARCHAR) AND n.[guid] = 'points'   

	-- bracket
    INSERT INTO @pools(pool_key, bracket_key, [rank], editable)
    SELECT p.pool_key, p.bracket_key, p.[rank], 0
      FROM dbo.UGC_Pools p
     INNER JOIN @brackets b
        ON b.bracket_key = p.bracket_key

    UPDATE p
       SET p.name = n.name, p.participants = n.participants
      FROM @pools p
     INNER JOIN dbo.UGC_Pool_Names n
        ON n.pool_key = p.pool_key

    UPDATE p
       SET p.editable = 1
      FROM @pools p
     INNER JOIN dbo.UGC_Pool_Names n
        ON  n.pool_key = p.pool_key AND n.[guid] = @guid


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
    (
        SELECT
        (
           SELECT 'true' AS 'json:Array',
                  p.pool_key, p.name, p.editable,
                  (
                      SELECT 'true' AS 'json:Array',
                             b.bracket_key
                        FROM @pools b
                       WHERE b.pool_key = p.pool_key AND b.bracket_key <> ''                       
                         FOR XML RAW('brackets'), TYPE                      
                  )
             FROM @pools p
            GROUP BY p.pool_key, p.name, p.editable
              FOR XML RAW('pools'), TYPE
        ),
        (
           SELECT 'true' AS 'json:Array',
                  winner_abbr, name, bracket_key, ISNULL(points_earned, '--') AS points_earned, ISNULL(points_total, '--') AS points_total,
                  ISNULL(picks_correct, '--') AS picks_correct, ISNULL(picks_total, '--') AS picks_total, ISNULL(points_remaining, '--') AS points_remaining,
                  (
                      SELECT 'true' AS 'json:Array',
                             p.pool_key, p.participants, ISNULL(p.[rank], '--') AS [rank], p.name
                        FROM @pools p
                       WHERE p.bracket_key = b.bracket_key
                         FOR XML RAW('pools'), TYPE
                  )
             FROM @brackets b
              FOR XML RAW('brackets'), TYPE
        )
        FOR XML RAW('profile'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END




GO
