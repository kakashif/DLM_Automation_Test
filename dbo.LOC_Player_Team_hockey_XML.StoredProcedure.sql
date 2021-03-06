USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Player_Team_hockey_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


create PROCEDURE [dbo].[LOC_Player_Team_hockey_XML]
    @seasonKey INT,
    @teamSlug VARCHAR(100),
    @playerId INT
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 04/29/2015
  -- Description: get hockey player statistics for USCP
  -- Update: 05/06/2015 - John Lin - add salary
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @player_key VARCHAR(100) = 'l.nhl.com-p.' + CAST(@playerId AS VARCHAR)
    DECLARE @sub_season_type VARCHAR(100) = 'pre-regular'

    IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Statistics WHERE season_key = @seasonKey AND sub_season_type = 'season-regular' AND player_key = @player_key)
    BEGIN
        SET @sub_season_type = 'season-regular'
    END

    DECLARE @player TABLE
    (
		player_key     VARCHAR(100),
		id             VARCHAR(100),
		uniform_number VARCHAR(100),
		position       VARCHAR(100),
		[weight]       INT,
        head_shot      VARCHAR(200),
        [filename]     VARCHAR(100),
		first_name     VARCHAR(100),
		last_name      VARCHAR(100),
		[status]       VARCHAR(100),
		captain        VARCHAR(100),
		dob            VARCHAR(100),
		shoots         VARCHAR(100),
		salary         VARCHAR(100)
    )
    INSERT INTO @player (player_key, uniform_number, position, [weight], head_shot, [filename], [status])
    SELECT player_key, uniform_number, position_regular, [weight], head_shot, [filename], phase_status
      FROM dbo.SMG_Rosters
     WHERE season_key = @seasonKey AND player_key = @player_key AND phase_status <> 'delete'

    UPDATE p
       SET p.first_name = sp.first_name, p.last_name = sp.last_name,
           p.dob = CAST(DATEPART(MONTH, sp.date_of_birth) AS VARCHAR) + '/' +
                   CAST(DATEPART(DAY, sp.date_of_birth) AS VARCHAR) + '/' +
                   CAST(DATEPART(YEAR, sp.date_of_birth) AS VARCHAR),
           p.shoots = sp.shooting_batting_hand
      FROM @player p
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = p.player_key

    -- embargo latest season
	DECLARE @embargo_season INT
	DECLARE @salary MONEY

	SELECT @embargo_season = season_key
	  FROM dbo.SMG_Default_Dates
	 WHERE league_key = 'nhl' AND page = 'salaries'

	IF (@embargo_season IS NULL)
	BEGIN
		SET @embargo_season = YEAR(GETDATE())
	END

	SELECT TOP 1 @salary = salary
	  FROM SportsEditDB.dbo.SMG_Salaries
	 WHERE season_key <= @embargo_season AND player_key = @player_key
	 ORDER BY season_key DESC

    UPDATE @player
       SET salary = '$' + REPLACE(CONVERT(VARCHAR, @salary, 1), '.00', '')

    UPDATE @player
       SET uniform_number = ''
     WHERE uniform_number IS NULL OR uniform_number = 0

    UPDATE @player
       SET head_shot = 'http://www.gannett-cdn.com/media/SMG/' + head_shot + '120x120/' + [filename]
     WHERE head_shot IS NOT NULL AND [filename] IS NOT NULL

    DECLARE @hockey TABLE
    (
        position VARCHAR(100),
        -- goaltending
        [events-played] VARCHAR(100),
        [goaltender-wins] VARCHAR(100),
        [goaltender-losses] VARCHAR(100),
        [goaltender-losses-overtime] VARCHAR(100),
        [goals-against-average] VARCHAR(100),
        [goals-allowed] VARCHAR(100),
        [shots-allowed] VARCHAR(100),
        [saves] VARCHAR(100),
        [save-percentage] VARCHAR(100),
        [shutouts] VARCHAR(100),
        -- season
        [time-played-event-average] VARCHAR(100),
        [goals] VARCHAR(100),
        [assists] VARCHAR(100),
        [points] VARCHAR(100),
        [plus-minus] VARCHAR(100),
        [points-per-game] VARCHAR(100),
        [shots] VARCHAR(100),
        [goals-game-winning] VARCHAR(100),
        [faceoff-wins] VARCHAR(100),
        [faceoff-losses] VARCHAR(100),
        [faceoff-win-percentage] VARCHAR(100),
        [goals-power-play] VARCHAR(100),
        [assists-power-play] VARCHAR(100),
        [goals-short-handed] VARCHAR(100),
        [assists-short-handed] VARCHAR(100),
        [penalty-minutes] VARCHAR(100),
        [penalty-minutes-per-game] VARCHAR(100),
        [penalty-count] VARCHAR(100),
        [goals-penalty-shot] VARCHAR(100),
        [goals-shootout-attempts] VARCHAR(100),
        [goals-shootout] VARCHAR(100),
        [shots-shootout-percentage] VARCHAR(100),
        [giveaways] VARCHAR(100),
        [takeaways] VARCHAR(100),
        [turnover-ratio] VARCHAR(100),
        [shots-blocked] VARCHAR(100),
        [hits] VARCHAR(100)
    )
    DECLARE @stats TABLE
    (
        [column] VARCHAR(100), 
        value    VARCHAR(100)
    )

    INSERT INTO @stats ([column], value)
    SELECT [column], value 
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE season_key = @seasonKey AND sub_season_type = @sub_season_type AND player_key = @player_key

    INSERT INTO @hockey ([events-played], [goaltender-wins], [goaltender-losses], [goaltender-losses-overtime],
                         [goals-against-average], [goals-allowed], [shots-allowed], [saves], [save-percentage], [shutouts],
                         [time-played-event-average], [goals], [assists], [points], [plus-minus], [points-per-game],
                         [shots], [goals-game-winning], [faceoff-wins], [faceoff-losses], [faceoff-win-percentage],
                         [goals-power-play], [assists-power-play], [goals-short-handed], [assists-short-handed],
                         [penalty-minutes], [penalty-minutes-per-game], [penalty-count], [goals-penalty-shot],
                         [goals-shootout-attempts], [goals-shootout], [shots-shootout-percentage], [giveaways],
                         [takeaways], [turnover-ratio], [shots-blocked], [hits])
    SELECT [events-played], [goaltender-wins], [goaltender-losses], [goaltender-losses-overtime],
           [goals-against-average], [goals-allowed], [shots-allowed], [saves], [save-percentage], [shutouts],
           [time-played-event-average], [goals], [assists], [points], [plus-minus], [points-per-game],
           [shots], [goals-game-winning], [faceoff-wins], [faceoff-losses], [faceoff-win-percentage],
           [goals-power-play], [assists-power-play], [goals-short-handed], [assists-short-handed],
           [penalty-minutes], [penalty-minutes-per-game], [penalty-count], [goals-penalty-shot],
           [goals-shootout-attempts], [goals-shootout], [shots-shootout-percentage], [giveaways],
           [takeaways], [turnover-ratio], [shots-blocked], [hits]
      FROM (SELECT [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [goaltender-wins], [goaltender-losses], [goaltender-losses-overtime],
                                            [goals-against-average], [goals-allowed], [shots-allowed], [saves], [save-percentage], [shutouts],
                                            [time-played-event-average], [goals], [assists], [points], [plus-minus], [points-per-game],
                                            [shots], [goals-game-winning], [faceoff-wins], [faceoff-losses], [faceoff-win-percentage],
                                            [goals-power-play], [assists-power-play], [goals-short-handed], [assists-short-handed],
                                            [penalty-minutes], [penalty-minutes-per-game], [penalty-count], [goals-penalty-shot],
                                            [goals-shootout-attempts], [goals-shootout], [shots-shootout-percentage], [giveaways],
                                            [takeaways], [turnover-ratio], [shots-blocked], [hits])) AS p

    UPDATE @hockey
       SET position = (SELECT position FROM @player WHERE player_key = @player_key)   


    UPDATE @hockey
       SET [events-played] = ISNULL([events-played], ''),
           [goaltender-wins] = ISNULL([goaltender-wins], ''),
           [goaltender-losses] = ISNULL([goaltender-losses], ''),
           [goaltender-losses-overtime] = ISNULL([goaltender-losses-overtime], ''),
           [goals-against-average] = ISNULL([goals-against-average], ''),
           [goals-allowed] = ISNULL([goals-allowed], ''),
           [shots-allowed] = ISNULL([shots-allowed], ''),
           [saves] = ISNULL([saves], ''),
           [save-percentage] = ISNULL([save-percentage], ''),
           [shutouts] = ISNULL([shutouts], '')
     WHERE position = 'G'

    UPDATE @hockey
       SET [events-played] = ISNULL([events-played], ''),
           [time-played-event-average] = ISNULL([time-played-event-average], ''),
           [goals] = ISNULL([goals], ''),
           [assists] = ISNULL([assists], ''),
           [points] = ISNULL([points], ''),
           [plus-minus] = ISNULL([plus-minus], ''),
           [points-per-game] = ISNULL([points-per-game], ''),
           [shots] = ISNULL([shots], ''),
           [goals-game-winning] = ISNULL([goals-game-winning], ''),
           [faceoff-wins] = ISNULL([faceoff-wins], ''),
           [faceoff-losses] = ISNULL([faceoff-losses], ''),
           [faceoff-win-percentage] = ISNULL([faceoff-win-percentage], ''),
           [goals-power-play] = ISNULL([goals-power-play], ''),
           [assists-power-play] = ISNULL([assists-power-play], ''),
           [goals-short-handed] = ISNULL([goals-short-handed], ''),
           [assists-short-handed] = ISNULL([assists-short-handed], ''),
           [penalty-minutes] = ISNULL([penalty-minutes], ''),
           [penalty-minutes-per-game] = ISNULL([penalty-minutes-per-game], ''),
           [penalty-count] = ISNULL([penalty-count], ''),
           [goals-penalty-shot] = ISNULL([goals-penalty-shot], ''),
           [goals-shootout-attempts] = ISNULL([goals-shootout-attempts], ''),
           [goals-shootout] = ISNULL([goals-shootout], ''),
           [shots-shootout-percentage] = ISNULL([shots-shootout-percentage], ''),
           [giveaways] = ISNULL([giveaways], ''),
           [takeaways] = ISNULL([takeaways], ''),
           [turnover-ratio] = ISNULL([turnover-ratio], ''),
           [shots-blocked] = ISNULL([shots-blocked], ''),
           [hits] = ISNULL([hits], '')




    SELECT
    (
	    SELECT id, uniform_number, position, [weight], head_shot, first_name, last_name, [status], captain, dob, shoots, salary
    	  FROM @player
    	 WHERE player_key = @player_key
           FOR XML RAW('player'), TYPE
    ),
    (
        SELECT [events-played], [goaltender-wins], [goaltender-losses], [goaltender-losses-overtime],
               [goals-against-average], [goals-allowed], [shots-allowed], [saves], [save-percentage], [shutouts]
          FROM @hockey
         WHERE position = 'G'
           FOR XML RAW('goaltending'), TYPE
    ),
    (
        SELECT [events-played], [time-played-event-average], [goals], [assists], [points], [plus-minus], [points-per-game], [shots],
               [goals-game-winning], [faceoff-wins], [faceoff-losses], [faceoff-win-percentage],
               [goals-power-play], [assists-power-play], [goals-short-handed], [assists-short-handed], [penalty-minutes],
               [penalty-minutes-per-game], [penalty-count], [goals-penalty-shot], [goals-shootout-attempts], [goals-shootout],
               [shots-shootout-percentage],  [giveaways], [takeaways], [turnover-ratio], [shots-blocked], [hits]
          FROM @hockey
           FOR XML RAW('season'), TYPE
    )
    FOR XML RAW('root'), TYPE

    SET NOCOUNT OFF
END 

GO
