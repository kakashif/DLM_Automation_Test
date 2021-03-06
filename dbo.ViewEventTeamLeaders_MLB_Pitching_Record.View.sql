USE [SportsDB]
GO
/****** Object:  View [dbo].[ViewEventTeamLeaders_MLB_Pitching_Record]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[ViewEventTeamLeaders_MLB_Pitching_Record]
-- =============================================
-- Author:		John Titchener
-- Create date: 8/1/2012
-- Description:	Gets Pitching statistics for MLB
-- =============================================
AS
SELECT
 	teams.team_key,
 	tdn.full_name,
    persons.person_key,
    dn.last_name,
    dn.first_name,
    s.season_key,
    ss.sub_season_type,
    ss.id AS sub_season_id,
	bps.era,
	bps.strikeouts,
	wins,
	losses,
	saves,
	shutouts,
	games_complete,
	games_finished,
	winning_percentage
	--,saves_blown
FROM

     dbo.seasons AS s  WITH (NOLOCK) 
     INNER JOIN dbo.sub_seasons AS ss  WITH (NOLOCK) 
		ON s.id = ss.season_id
		AND ss.sub_season_type = 'season-regular'
     INNER JOIN dbo.stats   WITH (NOLOCK) 
		ON stat_coverage_id = ss.id
		AND stats.stat_coverage_type = 'sub_seasons'
		AND stats.stat_coverage_id = ss.id
		AND stats.stat_holder_type = 'persons'
		AND stats.stat_repository_type = 'baseball_pitching_stats'
     INNER JOIN dbo.baseball_pitching_stats AS bps  WITH (NOLOCK) 
		ON bps.id = stats.stat_repository_id
     INNER JOIN dbo.persons   WITH (NOLOCK) 
		ON stats.stat_holder_id = persons.id
     INNER JOIN dbo.display_names AS dn  WITH (NOLOCK) 
		ON  dn.entity_id = persons.id
		AND dn.entity_type = 'persons'
	 INNER JOIN dbo.teams  WITH (NOLOCK) 
		ON stats.stat_membership_id = teams.id
		AND teams.publisher_id = (SELECT MAX(id) FROM dbo.publishers  WITH (NOLOCK) WHERE publisher_key = 'sportsnetwork.com')
	 INNER JOIN dbo.team_phases AS tp   WITH (NOLOCK) 
		ON tp.team_id = teams.id
	INNER JOIN dbo.affiliations  AS la  WITH (NOLOCK) 
		ON tp.affiliation_id = la.id 
		AND la.publisher_id = teams.publisher_id 
		AND la.affiliation_type = 'league'
		and la.affiliation_key = 'l.mlb.com'
     INNER JOIN dbo.display_names AS tdn  WITH (NOLOCK) 
		ON tdn.entity_id = teams.id
		AND tdn.entity_type = 'teams';

GO
