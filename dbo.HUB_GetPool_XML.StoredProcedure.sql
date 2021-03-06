USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetPool_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetPool_XML]
    @poolKey VARCHAR(100)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 01/26/2015
-- Description:	get bracket teams
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @first VARCHAR(100)
    DECLARE @last VARCHAR(100)

    SELECT @first = [first], @last = [last]
      FROM dbo.UGC_GUID_Names n
     INNER JOIN dbo.UGC_Pool_Names pn
        ON pn.[guid] = n.[guid] AND pn.pool_key = @poolKey
    
    DECLARE @name VARCHAR(100)
    DECLARE @comments VARCHAR(max)
    DECLARE @participants INT

    SELECT @name = name, @comments = comments, @participants = participants
      FROM dbo.UGC_Pool_Names
     WHERE pool_key = @poolKey
    
    DECLARE @pool TABLE 
	(
        [first] VARCHAR(100),
        [last] VARCHAR(100),
        [guid] VARCHAR(100),
	    bracket_key VARCHAR(100),
        name VARCHAR(100),
        winner_abbr VARCHAR(100),
        winner_logo VARCHAR(100),
        [rank] VARCHAR(100),
        points_earned VARCHAR(100),
        points_remaining VARCHAR(100),
        points_round_2 VARCHAR(100),
        points_round_3 VARCHAR(100),
        points_sweet_16 VARCHAR(100),
        points_elite_8 VARCHAR(100),
        points_final_4 VARCHAR(100),
        points_championship VARCHAR(100)
	)
	-- default creator guid
    INSERT INTO @pool (bracket_key, [guid], [rank])
    SELECT bracket_key, [guid], [rank]
      FROM dbo.UGC_Pools
     WHERE pool_key = @poolKey

    -- update user guid
    UPDATE p
       SET p.name = n.name,  p.winner_abbr = n.winner_abbr, p.points_earned = n.points_earned,
           p.points_remaining = n.points_remaining, p.points_round_2 = n.points_round_2,
           p.points_round_3 = n.points_round_3, p.points_sweet_16 = n.points_sweet_16,
           p.points_elite_8 = n.points_elite_8, p.points_final_4 = n.points_final_4,
           p.points_championship = n.points_championship, p.[guid] = n.[guid]
      FROM @pool p
     INNER JOIN dbo.UGC_Bracket_Names n
        ON n.bracket_key = p.bracket_key

    UPDATE p
       SET p.[first] = n.[first], p.[last] = n.[last]
      FROM @pool p
     INNER JOIN dbo.UGC_GUID_Names n
        ON n.[guid] = p.[guid]

    UPDATE @pool
       SET winner_logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/80/' + winner_abbr + '.png'



    IF (@name = 'Top 100 Leaderboard')
    BEGIN
        ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
        SELECT @first AS [first], @last AS [last], @name AS name, ISNULL(@comments, '') AS comments, @participants AS participants,
        (
               SELECT TOP 100
                      'true' AS 'json:Array',
                      [first], [last], bracket_key, ISNULL(name, '') AS name, ISNULL(winner_abbr, '') AS winner_abbr,
                      ISNULL(winner_logo, '') AS winner_logo, ISNULL([rank], '--') AS [rank],
                      ISNULL(points_earned, '--') AS points_earned, ISNULL(points_remaining, '--') AS points_remaining,
                      ISNULL(points_round_2, '--') AS points_round_2, ISNULL(points_round_3, '--') AS points_round_3,
                      ISNULL(points_sweet_16, '--') AS points_sweet_16, ISNULL(points_elite_8, '--') AS points_elite_8,
                      ISNULL(points_final_4, '--') AS points_final_4, ISNULL(points_championship, '--') AS points_championship
                 FROM @pool
                ORDER BY CAST([rank] AS INT) ASC, CAST(points_remaining AS INT) DESC
                  FOR XML RAW('pool'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    
        RETURN
    END



    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT @first AS [first], @last AS [last], @name AS name, ISNULL(@comments, '') AS comments, @participants AS participants,
    (
           SELECT 'true' AS 'json:Array',
                  [first], [last], bracket_key, ISNULL(name, '') AS name, ISNULL(winner_abbr, '') AS winner_abbr,
                  ISNULL(winner_logo, '') AS winner_logo, ISNULL([rank], '--') AS [rank],
                  ISNULL(points_earned, '--') AS points_earned, ISNULL(points_remaining, '--') AS points_remaining,
                  ISNULL(points_round_2, '--') AS points_round_2, ISNULL(points_round_3, '--') AS points_round_3,
                  ISNULL(points_sweet_16, '--') AS points_sweet_16, ISNULL(points_elite_8, '--') AS points_elite_8,
                  ISNULL(points_final_4, '--') AS points_final_4, ISNULL(points_championship, '--') AS points_championship
             FROM @pool
            ORDER BY CAST([rank] AS INT) ASC, CAST(points_remaining AS INT) DESC
              FOR XML RAW('pool'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
	    
    SET NOCOUNT OFF;
END




GO
