USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Player_basketball_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[LOC_Player_basketball_XML]
    @leagueName VARCHAR(100),
    @playerId INT
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 04/29/2015
  -- Description: get basketball player statistics for USCP
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @player_key VARCHAR(100) = 'l.nba.com-p.' + CAST(@playerId AS VARCHAR)
    DECLARE @sub_season_type VARCHAR(100) = 'pre-regular'

    IF (@leagueName IN ('nba', 'wnba'))
    BEGIN
        IF (@leagueName = 'wnba')
        BEGIN
            SET @player_key = 'l.wnba.com-p.' + CAST(@playerId AS VARCHAR)
        END
        
        IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Statistics WHERE sub_season_type = 'season-regular' AND player_key = @player_key)
        BEGIN
            SET @sub_season_type = 'season-regular'
        END
    END
    ELSE
    BEGIN
        IF (@leagueName = 'ncaab')
        BEGIN
            SET @player_key = 'l.ncaa.org.mbasket-p.' + CAST(@playerId AS VARCHAR)
        END
        ELSE
        BEGIN
            SET @player_key = 'l.ncaa.org.wbasket-p.' + CAST(@playerId AS VARCHAR)
        END

        SET @sub_season_type = 'season-regular'
    END

    DECLARE @player TABLE
    (
        player_key     VARCHAR(100),
        id             VARCHAR(100),
        uniform_number VARCHAR(100),
        position       VARCHAR(100),
        height         VARCHAR(100),
        [weight]       INT,
        head_shot      VARCHAR(200),
        [filename]     VARCHAR(100),
        first_name     VARCHAR(100),
        last_name      VARCHAR(100),
        [status]       VARCHAR(100),
        college        VARCHAR(100),
   		class          VARCHAR(100)
    )
    INSERT INTO @player (player_key, uniform_number, position, height, [weight], head_shot, [filename], [status], class)
    SELECT player_key, uniform_number, position_regular, height, [weight], head_shot, [filename], phase_status, subphase_type
      FROM dbo.SMG_Rosters
     WHERE player_key = @player_key AND phase_status <> 'delete'
                 
    UPDATE p
       SET p.first_name = sp.first_name, p.last_name = sp.last_name,
           p.college = sp.college_name
      FROM @player p
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = p.player_key

    UPDATE @player
       SET uniform_number = ''           
     WHERE uniform_number IS NULL OR uniform_number = 0

    UPDATE @player
       SET head_shot = 'http://www.gannett-cdn.com/media/SMG/' + head_shot + '120x120/' + [filename]
     WHERE head_shot IS NOT NULL AND [filename] IS NOT NULL

    DECLARE @basketball TABLE
    (
        [events-played] VARCHAR(100),
        [minutes-played] VARCHAR(100),
        [minutes-played-per-game] VARCHAR(100),
        [points-scored-for] VARCHAR(100),
        [points-scored-for-per-game] VARCHAR(100),
        [points-scored-per-game-highest] VARCHAR(100),
        [assists-total] VARCHAR(100),
        [assists-total-per-game] VARCHAR(100),
        [rebounds-total] VARCHAR(100),
        [rebounds-offensive] VARCHAR(100),
        [rebounds-defensive] VARCHAR(100),
        [rebounds-offensive-per-game] VARCHAR(100),
        [rebounds-defensive-per-game] VARCHAR(100),
        [rebounds-per-game] VARCHAR(100),
        [blocks-total] VARCHAR(100),
        [blocks-per-game] VARCHAR(100),
        [steals-total] VARCHAR(100),
        [steals-per-game] VARCHAR(100),
        [field-goals-made] VARCHAR(100),
        [field-goals-attempted] VARCHAR(100),
        [field-goals-percentage] VARCHAR(100),
        [three-pointers-made] VARCHAR(100),
        [three-pointers-attempted] VARCHAR(100),
        [three-pointers-percentage] VARCHAR(100),
        [free-throws-made] VARCHAR(100),
        [free-throws-attempted] VARCHAR(100),
        [free-throws-percentage] VARCHAR(100),
        [personal-fouls] VARCHAR(100),
        [personal-fouls-per-game] VARCHAR(100),
        [turnovers-total] VARCHAR(100),
        [turnovers-total-per-game] VARCHAR(100)
    )        
    DECLARE @stats TABLE
    (
        [column] VARCHAR(100), 
        value    VARCHAR(100)
    )

    INSERT INTO @stats ([column], value)
    SELECT [column], value
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE sub_season_type = @sub_season_type AND player_key = @player_key
     
    INSERT INTO @basketball([events-played], [minutes-played], [minutes-played-per-game], [points-scored-for],
                            [points-scored-for-per-game], [points-scored-per-game-highest], [assists-total],
                            [assists-total-per-game], [rebounds-total], [rebounds-offensive], [rebounds-defensive],
                            [rebounds-offensive-per-game], [rebounds-defensive-per-game], [rebounds-per-game],
                            [blocks-total], [blocks-per-game], [steals-total], [steals-per-game], [field-goals-made],
                            [field-goals-attempted], [field-goals-percentage], [three-pointers-made],
                            [three-pointers-attempted], [three-pointers-percentage], [free-throws-made],
                            [free-throws-attempted], [free-throws-percentage], [personal-fouls],
                            [personal-fouls-per-game], [turnovers-total], [turnovers-total-per-game])
        SELECT [events-played], [minutes-played], [minutes-played-per-game], [points-scored-for],
               [points-scored-for-per-game], [points-scored-per-game-highest], [assists-total],
               [assists-total-per-game], [rebounds-total], [rebounds-offensive], [rebounds-defensive],
               [rebounds-offensive-per-game], [rebounds-defensive-per-game], [rebounds-per-game],
               [blocks-total], [blocks-per-game], [steals-total], [steals-per-game], [field-goals-made],
               [field-goals-attempted], [field-goals-percentage], [three-pointers-made],
               [three-pointers-attempted], [three-pointers-percentage], [free-throws-made],
               [free-throws-attempted], [free-throws-percentage], [personal-fouls],
               [personal-fouls-per-game], [turnovers-total], [turnovers-total-per-game]
          FROM (SELECT [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [minutes-played], [minutes-played-per-game], [points-scored-for],
                                                [points-scored-for-per-game], [points-scored-per-game-highest], [assists-total],
                                                [assists-total-per-game], [rebounds-total], [rebounds-offensive], [rebounds-defensive],
                                                [rebounds-offensive-per-game], [rebounds-defensive-per-game], [rebounds-per-game],
                                                [blocks-total], [blocks-per-game], [steals-total], [steals-per-game], [field-goals-made],
                                                [field-goals-attempted], [field-goals-percentage], [three-pointers-made],
                                                [three-pointers-attempted], [three-pointers-percentage], [free-throws-made],
                                                [free-throws-attempted], [free-throws-percentage], [personal-fouls],
                                                [personal-fouls-per-game], [turnovers-total], [turnovers-total-per-game])) AS p

    UPDATE @basketball
       SET [events-played] = ISNULL([events-played], ''),
           [minutes-played] = ISNULL([minutes-played], ''),
           [minutes-played-per-game] = ISNULL([minutes-played-per-game], ''),
           [points-scored-for] = ISNULL([points-scored-for], ''),
           [points-scored-for-per-game] = ISNULL([points-scored-for-per-game], ''),
           [points-scored-per-game-highest] = ISNULL([points-scored-per-game-highest], ''),
           [assists-total] = ISNULL([assists-total], ''),
           [assists-total-per-game] = ISNULL([assists-total-per-game], ''),
           [rebounds-total] = ISNULL([rebounds-total], ''),
           [rebounds-offensive] = ISNULL([rebounds-offensive], ''),
           [rebounds-defensive] = ISNULL([rebounds-defensive], ''),
           [rebounds-offensive-per-game] = ISNULL([rebounds-offensive-per-game], ''),
           [rebounds-defensive-per-game] = ISNULL([rebounds-defensive-per-game], ''),
           [rebounds-per-game] = ISNULL([rebounds-per-game], ''),
           [blocks-total] = ISNULL([blocks-total], ''),
           [blocks-per-game] = ISNULL([blocks-per-game], ''),
           [steals-total] = ISNULL([steals-total], ''),
           [steals-per-game] = ISNULL([steals-per-game], ''),
           [field-goals-made] = ISNULL([field-goals-made], ''),
           [field-goals-attempted] = ISNULL([field-goals-attempted], ''),
           [field-goals-percentage] = ISNULL([field-goals-percentage], ''),
           [three-pointers-made] = ISNULL([three-pointers-made], ''),
           [three-pointers-attempted] = ISNULL([three-pointers-attempted], ''),
           [three-pointers-percentage] = ISNULL([three-pointers-percentage], ''),
           [free-throws-made] = ISNULL([free-throws-made], ''),
           [free-throws-attempted] = ISNULL([free-throws-attempted], ''),
           [free-throws-percentage] = ISNULL([free-throws-percentage], ''),
           [personal-fouls] = ISNULL([personal-fouls], ''),
           [personal-fouls-per-game] = ISNULL([personal-fouls-per-game], ''),
           [turnovers-total] = ISNULL([turnovers-total], ''),
           [turnovers-total-per-game] = ISNULL([turnovers-total-per-game], '')




    SELECT
    (
        SELECT uniform_number, position, height, [weight], head_shot, first_name, last_name, [status], college, class
          FROM @player
         WHERE player_key = @player_key
           FOR XML RAW('player'), TYPE
    ),
    (
        SELECT [events-played], [minutes-played], [minutes-played-per-game], [points-scored-for],
               [points-scored-for-per-game], [points-scored-per-game-highest], [assists-total],
               [assists-total-per-game], [rebounds-total], [rebounds-offensive], [rebounds-defensive],
               [rebounds-offensive-per-game], [rebounds-defensive-per-game], [rebounds-per-game],
               [blocks-total], [blocks-per-game], [steals-total], [steals-per-game], [field-goals-made],
               [field-goals-attempted], [field-goals-percentage], [three-pointers-made],
               [three-pointers-attempted], [three-pointers-percentage], [free-throws-made],
               [free-throws-attempted], [free-throws-percentage], [personal-fouls],
               [personal-fouls-per-game], [turnovers-total], [turnovers-total-per-game]
          FROM @basketball
           FOR XML RAW('season'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END 

GO
