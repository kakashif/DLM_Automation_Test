USE [SportsDB]
GO
/****** Object:  View [dbo].[ViewEventsPlayed]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[ViewEventsPlayed]
AS
-- =============================================
-- Author:		John Titchener
-- Create date: 8/1/2012
-- Description:	Gets Events Played statistics for all leagues
-- =============================================
	SELECT	a.affiliation_key AS league_key
			, seasons.season_key
			, ss.id AS sub_season_id
			, t.team_key
			, p.person_key
			, p.id AS person_id
			, p.publisher_id
			, dn_player.first_name
			, dn_player.last_name
			, core.events_played
			--, core.time_played_event_average
			--, core.time_played_event
	FROM	sub_seasons AS ss  WITH (NOLOCK) 
	INNER JOIN seasons  WITH (NOLOCK)  
		ON ss.season_id = seasons.id
	INNER JOIN affiliations AS a  WITH (NOLOCK) 
		ON seasons.league_id = a.id
		AND a.affiliation_type = 'league'
	INNER JOIN stats AS s  WITH (NOLOCK) 
		ON s.stat_coverage_type = 'sub_seasons' 
		AND s.stat_coverage_id = ss.id
	INNER JOIN core_stats AS core  WITH (NOLOCK) 
		ON s.stat_repository_id = core.id 
		AND s.stat_repository_type = 'core_stats'
	INNER JOIN display_names AS dn_player  WITH (NOLOCK) 
		ON dn_player.entity_id = s.stat_holder_id 
		AND dn_player.entity_type = 'persons' 
		AND s.stat_holder_type = 'persons'
	INNER JOIN persons AS p  WITH (NOLOCK) 
		ON s.stat_holder_id = p.id
	INNER JOIN teams AS t  WITH (NOLOCK) 
		ON s.stat_membership_id = t.id
	INNER JOIN publishers AS pub  WITH (NOLOCK) 
		ON seasons.publisher_id = pub.id

	WHERE pub.publisher_key = 'sportsnetwork.com';
	


GO
