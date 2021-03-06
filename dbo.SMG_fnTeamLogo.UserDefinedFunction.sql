USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnTeamLogo]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[SMG_fnTeamLogo]
(
    @leagueName VARCHAR(100),
    @teamAbbr VARCHAR(100),
    @logoSize VARCHAR(100)
)
RETURNS VARCHAR(100)
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 07/29/2015
-- Description: return a team logo url
-- =============================================
BEGIN

    DECLARE @logo_url VARCHAR(100)
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/'
    DECLARE @flag_folder VARCHAR(100) = 'countries/flags/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'


    IF (@leagueName IN ('ncaa', 'ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        SET @logo_url = @logo_prefix + 'ncaa' + @logo_folder + @logoSize + '/' + @teamAbbr + @logo_suffix
    END
    ELSE IF (@leagueName IN ('epl', 'champions'))
    BEGIN
        SET @logo_url = @logo_prefix + 'euro' + @logo_folder + @logoSize + '/' + @teamAbbr + @logo_suffix
    END
    ELSE IF (@leagueName IN ('natl', 'wwc'))
    BEGIN
        SET @logo_url = @logo_prefix + @flag_folder + @logoSize + '/' + @teamAbbr + @logo_suffix
    END
    ELSE
    BEGIN
        -- CON.png hack for Windows reserved word
        SET @logo_url = @logo_prefix + @leagueName + @logo_folder + @logoSize + '/' +
                         CASE
                             WHEN @teamAbbr = 'CON' THEN 'CON_'
                             ELSE @teamAbbr
                         END + @logo_suffix
    END

    RETURN @logo_url
END


GO
