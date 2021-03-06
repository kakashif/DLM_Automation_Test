USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SYS_GetLastUpdate_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SYS_GetLastUpdate_XML] 
AS
-- =============================================
-- Author:      John Lin
-- Create date: 01/07/2015
-- Description: get last update date time
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 


    DECLARE @xmlteam_schedule VARCHAR(100)
    DECLARE @datafactory_schedule VARCHAR(100)
    DECLARE @xmlteam_score VARCHAR(100)
    DECLARE @datafactory_score VARCHAR(100)

    -- schedule
    SELECT @xmlteam_schedule = MAX(date_time)
      FROM dbo.SMG_Schedules
     WHERE league_key IN ('l.mlb.com', 'l.mlsnet.com', 'l.nba.com',
                          'l.ncaa.org.mbasket', 'l.ncaa.org.mfoot', 'l.ncaa.org.wbasket',
                          'l.nfl.com', 'l.nhl.com', 'l.wnba.com')

    SELECT @datafactory_schedule = MAX(date_time)
      FROM dbo.SMG_Schedules
     WHERE league_key IN ('premierleague', 'champions')

    -- score
    SELECT @xmlteam_score = MAX(date_time)
      FROM dbo.SMG_Scores
     WHERE league_key IN ('l.mlb.com', 'l.mlsnet.com', 'l.nba.com',
                          'l.ncaa.org.mbasket', 'l.ncaa.org.mfoot', 'l.ncaa.org.wbasket',
                          'l.nfl.com', 'l.nhl.com', 'l.wnba.com')

    SELECT @datafactory_score = MAX(date_time)
      FROM dbo.SMG_Scores
     WHERE league_key IN ('premierleague', 'champions')


    SELECT
	(
        SELECT @xmlteam_schedule AS xmlteam_schedule, @datafactory_schedule AS datafactory_schedule,
               @xmlteam_score AS xmlteam_score, @datafactory_score AS datafactory_score 
           FOR XML PATH(''), TYPE
    )
    FOR XML PATH(''), ROOT('root')
        
    SET NOCOUNT OFF;
END

GO
