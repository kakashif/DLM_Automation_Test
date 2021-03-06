USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[getSeasonByLeague]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[getSeasonByLeague] @leagueKey varchar(max),
	@date datetime
	
AS
-- =============================================
-- Author:		Ramya Rangarajan
-- Create date: 17 Mar 2009
-- Description:	SProc to get the current season by League
-- Update: 02/21/2013 - John Lin - remove bad join that exclude sports without post season
--         08/05/2013 - John Lin - unsupress NFL pre season
--         05/21/2015 - DO NOT DELETE until /Schedules.svc/TeamIndex/league_key/ is refactored
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON

	IF (@leagueKey IS NULL)
	BEGIN
		RETURN;
	END
		
	DECLARE @publisherId int
	SET @publisherId = (SELECT id FROM publishers WHERE publisher_key = 'sportsnetwork.com')

	--Add GSM publisher id for International Soccer Leagues
	DECLARE @pubIdGSM int
	SET @pubIdGSM = (SELECT id FROM publishers WHERE publisher_key = 'globalsportsmedia.com');

	--Add ESA publisher id for International Soccer Leagues
	DECLARE @pubIdESA int
	SET @pubIdESA = (SELECT id FROM publishers WHERE publisher_key = 'esagroup.co.uk');


	
	DECLARE @tmpResults TABLE (		[rank] INT,
									sub_season_id INT,								
									sub_season_type VARCHAR(100),
									sub_season_key VARCHAR(100),
									league_key VARCHAR(200),
									season_key VARCHAR(50),
									season_start_date SMALLDATETIME,
									season_end_date SMALLDATETIME)
	

	--in season
	INSERT INTO @tmpResults
	SELECT		row_number() OVER (PARTITION BY la.affiliation_key ORDER BY s.season_key DESC ,ss.start_date_time DESC),
				ss.id,
				ss.sub_season_type, 
				ss.sub_season_key, 
				la.affiliation_key as league_key, 
				s.season_key ,
				ISNULL(ss.start_date_time,'') as season_start_date,
				ISNULL(ss.end_date_time,'') as season_end_date
	FROM		affiliations la WITH(NOLOCK)
	INNER JOIN	seasons s WITH(NOLOCK) 
			ON	la.id = s.league_id
			AND	s.publisher_id = la.publisher_id	
	INNER JOIN	sub_seasons ss WITH(NOLOCK) ON s.id= ss.season_id
	WHERE		(la.publisher_id = @publisherId OR la.publisher_id = @pubIdESA) 
			AND	la.affiliation_type='league' 
			AND	ss.start_date_time IS NOT NULL 
			AND	ss.end_date_time IS NOT NULL 
			AND	@date BETWEEN ss.start_date_time AND ss.end_date_time 
			AND	la.affiliation_key IN (SELECT * FROM dbo.fnSplitString(@leagueKey,','))

	-- Get the season that's yet to start
	IF ((SELECT COUNT(DISTINCT league_key) FROM @tmpResults) <> (SELECT COUNT(*) FROM dbo.fnSplitString(@leagueKey,','))) 
	BEGIN
		INSERT INTO @tmpResults
		SELECT		row_number() OVER (PARTITION BY la.affiliation_key ORDER BY s.season_key DESC ,ss.start_date_time ASC),
					ss.id,
					ss.sub_season_type, 
					ss.sub_season_key, 
					la.affiliation_key as league_key, 
					s.season_key,
					ISNULL(ss.start_date_time,'') as season_start_date,
					ISNULL(ss.end_date_time,'') as season_end_date 
		FROM		affiliations la WITH(NOLOCK)
		INNER JOIN	seasons s WITH(NOLOCK) 
				ON	la.id = s.league_id
				AND	s.publisher_id = la.publisher_id	
		INNER JOIN	sub_seasons ss WITH(NOLOCK) 
				ON	s.id = ss.season_id
--
-- BAD: join excludes sports without post season
--				
--		INNER JOIN	events_sub_seasons ess WITH(NOLOCK) 
--				ON	ess.sub_season_id = ss.id 
--				AND ess.event_id = (SELECT MAX(event_id) FROM events_sub_seasons WITH(NOLOCK) WHERE sub_season_id = ss.id)
		WHERE		(la.publisher_id = @publisherId OR la.publisher_id = @pubIdESA) 
				AND	la.affiliation_type='league' 
				AND	la.affiliation_key IN (SELECT * FROM dbo.fnSplitString(@leagueKey,','))
				AND	la.affiliation_key NOT IN (SELECT league_key FROM @tmpResults)
				AND	ss.start_date_time >= @date		


		-- Get the latest season that got over		
		IF ((SELECT COUNT(DISTINCT league_key) FROM @tmpResults) <> (SELECT COUNT(*) FROM dbo.fnSplitString(@leagueKey,','))) 
		BEGIN
			INSERT INTO @tmpResults
			SELECT		row_number() OVER (PARTITION BY la.affiliation_key ORDER BY s.season_key DESC ,ss.start_date_time DESC),
						ss.id,
						ss.sub_season_type, 
						ss.sub_season_key, 
						la.affiliation_key as league_key, 
						s.season_key,
						ISNULL(ss.start_date_time,'') as season_start_date,
						ISNULL(ss.end_date_time,'') as season_end_date 
			FROM		affiliations la WITH(NOLOCK)
			INNER JOIN	seasons s WITH(NOLOCK) 
					ON	la.id = s.league_id
					AND	s.publisher_id = la.publisher_id	
			INNER JOIN	sub_seasons ss WITH(NOLOCK) 
					ON	s.id = ss.season_id
--
-- BAD: join excludes sports without post season
--				
--			INNER JOIN	events_sub_seasons ess WITH(NOLOCK) 
--					ON	ess.sub_season_id = ss.id 
--					AND ess.event_id = (SELECT MAX(event_id) FROM events_sub_seasons WITH(NOLOCK) WHERE sub_season_id = ss.id)
			WHERE		(la.publisher_id = @publisherId OR la.publisher_id = @pubIdESA) 
					AND	la.affiliation_type='league' 
					AND	la.affiliation_key IN (SELECT * FROM dbo.fnSplitString(@leagueKey,',')) 
					AND	la.affiliation_key NOT IN (SELECT league_key FROM @tmpResults)
					AND	ss.start_date_time <= @date
			
		-- Get the latest season and subseason available (with no join to events - for golf, tennis)	
		IF ((SELECT COUNT(DISTINCT league_key) FROM @tmpResults) <> (SELECT COUNT(*) FROM dbo.fnSplitString(@leagueKey,','))) 
			BEGIN
				INSERT INTO @tmpResults
				SELECT		row_number() OVER (PARTITION BY la.affiliation_key ORDER BY s.season_key DESC ,ss.start_date_time DESC),
							ss.id,
							ss.sub_season_type, 
							ss.sub_season_key, 
							la.affiliation_key as league_key, 
							s.season_key,
							ISNULL(ss.start_date_time,'') as season_start_date,
							ISNULL(ss.end_date_time,'') as season_end_date 
				FROM		affiliations la WITH(NOLOCK)
				INNER JOIN	seasons s WITH(NOLOCK) 
						ON	la.id = s.league_id
						AND	s.publisher_id = la.publisher_id	
				INNER JOIN	sub_seasons ss WITH(NOLOCK) 
						ON	s.id = ss.season_id
				WHERE		(la.publisher_id = @publisherId OR la.publisher_id = @pubIdESA)
						AND	la.affiliation_type='league' 
						AND	la.affiliation_key IN (SELECT * FROM dbo.fnSplitString(@leagueKey,','))
						AND	la.affiliation_key NOT IN (SELECT league_key FROM @tmpResults)
				ORDER BY	s.season_key DESC , 
							ss.start_date_time DESC
								
			END
		END		
	END

/*	
	IF (@leagueKey = 'l.nfl.com')
	BEGIN
	   DELETE FROM @tmpResults
	    WHERE sub_season_type = 'pre-season'
	END
*/
	
	IF EXISTS
	(
		SELECT		res.sub_season_id,
					res.league_key,
					res.season_key, 
					res.sub_season_type, 
					res.sub_season_key,
					res.season_start_date, 
					res.season_end_date
		FROM		@tmpResults as res
		WHERE		[rank] = 1		
	)
	BEGIN
		SELECT		res.[rank],
					res.sub_season_id,
					res.league_key,
					res.season_key, 
					res.sub_season_type, 
					res.sub_season_key,
					res.season_start_date, 
					res.season_end_date
		FROM		@tmpResults as res
		WHERE		[rank] = 1	
	END
	ELSE
	BEGIN
		SELECT * FROM @tmpResults
	END		
SET NOCOUNT OFF;
END


GO
