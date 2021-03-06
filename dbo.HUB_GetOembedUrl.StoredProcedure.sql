USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetOembedUrl]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetOembedUrl]
    @url VARCHAR(200)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 09/30/2015
-- Description:	generate oembed service based on url
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    --DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

	DECLARE @oembed TABLE (
		version VARCHAR(100),
		type VARCHAR(100),
		original_type VARCHAR(100),
		provider_name VARCHAR(100),
		provider_url VARCHAR(200),
		description VARCHAR(200),
		title VARCHAR(200),
		url VARCHAR(200),
		html VARCHAR(MAX),
		height VARCHAR(100),
		width VARCHAR(100),
		thumbnail_url VARCHAR(200)
	)

	INSERT INTO @oembed (version, provider_name, provider_url, type, url)
	VALUES ('1.0', 'USA TODAY', 'http://www.usatoday.com/sports', 'rich', @url)

	IF (@url LIKE 'http://www.usatoday.com/sports/%')
	BEGIN
		UPDATE @oembed
		   SET title = REPLACE(UPPER(@url), 'http://www.usatoday.com/sports/', 'USA Today | Sports | ')

		UPDATE @oembed
		   SET title = LEFT(title, CHARINDEX('/', title) - 1)
	END
	ELSE
	BEGIN
		UPDATE @oembed
		   SET title = 'USA Today | Sports'
	END

	IF (@url LIKE '%/boxscore%')
	BEGIN
		UPDATE @oembed
		   SET title = title + ' | Boxscore', original_type = 'rich', width = 540, height = 166

		UPDATE @oembed
		   SET html = '<iframe src="' + @url + 'oembed/?mobile=true" style="margin: 0; border: 0;" width="' + width + 
			   '" height="' + height + '" marginHeight="0" marginWidth="0" scrolling="no" frameBorder="0"></iframe>'
	END
	ELSE IF (@url LIKE '%/leaderboard%')
	BEGIN
		UPDATE @oembed
		   SET title = title + ' | Leaderboard', original_type = 'rich', width = 540,
			   height = dbo.HUB_fn_Leaderboard_Height(@url)

		UPDATE @oembed
		   SET html = '<iframe src="' + @url + 'oembed/" style="margin: 0; border: 0;" width="' + width + 
			   '" height="' + height + '" marginHeight="0" marginWidth="0" scrolling="no" frameBorder="0"></iframe>'
	END
	ELSE
	BEGIN

		UPDATE @oembed
		   SET thumbnail_url = 'http://www.gannett-cdn.com/static/images/logos/sports.png',
			   original_type = 'link', html = '<style>
.oembed-asset-link { background: #fff; border-bottom: 1px solid #e1e1e1; }
.oembed-link-anchor { display: block; clear: both; }
.oembed-link-thumbnail{ float: left; padding: 14px; }
.oembed-link-thumbnail img { max-width: 78px; max-height: 60px; display: block; }
p.oembed-link-title { font-size: 75%; color: #009BFF; margin: 0 14px; padding-top: 12px; font-weight:normal; text-align: left; line-height: 120%; }
p.oembed-link-desc { font-size: 100%; color: #666; font-weight: normal; margin: 0 14px 14px 14px; font-family: ''Futura Today Light''; text-align: left; line-height: 120%; }
</style>

<div class="oembed-asset oembed-asset-link oembed-asset-usa-today">
    <a href="http://www.usatoday.com/sports/mlb/scores/" class="oembed-link-anchor">
        <div class="oembed-link-thumbnail"><img src="http://www.gannett-cdn.com/-mm-/9065941e142eb769bb76794c742e08d1e14ee558/r=300/http/www.gannett-cdn.com/static/images/logos/sports.png" /></div>
        <p class="oembed-link-title">USA TODAY Sports</p>
        <p class="oembed-link-desc">USA TODAY | Sports</p>
        <div style="clear: both;"></div>
    </a>
</div>'	
	END

	UPDATE @oembed
	  SET description = REPLACE(title, ' | ', ', ')

    SELECT version, type, original_type, provider_name, provider_url, description, title, url,
		   html, height, width, thumbnail_url
	  FROM @oembed
       FOR XML PATH(''), ROOT('root')
	    
    SET NOCOUNT OFF;
END

GO
