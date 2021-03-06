USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetFiltersSoccer_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetFiltersSoccer_XML]
AS
--=============================================
-- Author:		ikenticus
-- Create date:	09/15/2014
-- Description:	get soccer filters for jameson
-- Update:		05/15/2015 - ikenticus: adding WWC
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


    DECLARE @filters TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        display VARCHAR(100),
        endpoint VARCHAR(100),
        league_name VARCHAR(100)
    )
    
	INSERT INTO @filters (display, league_name)
	VALUES	('MLS', 'mls'),
			('EPL', 'epl'),
			('Champions League', 'champions'),
			('Women''s World Cup', 'wwc')

	UPDATE @filters
	   SET endpoint = '/Scores.svc/' + league_name

   	SELECT (
               SELECT display, endpoint
                 FROM @filters
                ORDER BY id ASC
     			  FOR XML RAW('filters'), TYPE
           )
       FOR XML PATH(''), ROOT('root')

END


GO
