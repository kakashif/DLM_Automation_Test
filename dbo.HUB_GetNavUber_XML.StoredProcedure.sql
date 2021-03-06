USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNavUber_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNavUber_XML]
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 08/07/2014
-- Description:	Get uber nav for SportsHub
-- Updated:		09/15/2014 - fix url for topic pages
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


	DECLARE @sections TABLE (
		section VARCHAR(100),
		name VARCHAR(100),
		slug VARCHAR(100),
		url VARCHAR(100),
		selected VARCHAR(100),
		[order] INT
	)

	INSERT INTO @sections ([order], section, name, slug, url, selected)
	SELECT menu_order, front_name, menu_name, pagetype, link_href, 'false'
	  FROM SportsEditDB.dbo.SMG_Sports_Nav_Menu
	 WHERE front_name IN ('main-section', 'sports', 'social-links') AND pagetype != 'more'

	UPDATE @sections
	   SET section = 'sports-section'
	 WHERE section = 'sports'

	UPDATE @sections
	   SET selected = 'true'
	 WHERE section = 'main-section' AND slug = 'sports'

	INSERT INTO @sections ([order], section, name, slug)
	SELECT menu_order, 'sports-section', menu_name, pagetype
	  FROM SportsEditDB.dbo.SMG_Sports_Nav_Menu
	 WHERE front_name = 'sports' AND pagetype = 'more'
	 GROUP BY menu_order, menu_name, pagetype

	INSERT INTO @sections ([order], section, name, slug, url, selected)
	SELECT link_order, 'sports-more', link_name, REPLACE(LOWER(link_name), ' ', '-'), link_href, 'false'
	  FROM SportsEditDB.dbo.SMG_Sports_Nav_Menu
	 WHERE front_name = 'sports' AND pagetype = 'more'

	UPDATE @sections
	   SET slug = REPLACE(REPLACE(url, '/sports/', ''), '/', ''), url = 'http://www.usatoday.com' + url
	 WHERE url LIKE '/sports/%'

	UPDATE @sections
	   SET url = 'http://www.usatoday.com' + url
	 WHERE url LIKE '/topic/%'


	SELECT
		(
			SELECT name, slug, url, selected
			  FROM @sections
			 WHERE section = 'main-section'
			 ORDER BY [order]
			   FOR XML RAW('main-section'), TYPE
		),
		(
			SELECT name, slug, url,
				(
					SELECT name, slug, url
					  FROM @sections
					 WHERE section = 'sports-' + s.name
					   FOR XML PATH('children'), TYPE
				)
			  FROM @sections AS s
			 WHERE section = 'sports-section'
			 ORDER BY [order]
			   FOR XML RAW('sports-section'), TYPE
		),
		(
			SELECT slug, url
			  FROM @sections
			 WHERE section = 'social-links'
			 ORDER BY [order]
			   FOR XML RAW('social-links'), TYPE
		)
	FOR XML PATH(''), ROOT('root')

    
    SET NOCOUNT OFF;
END

GO
