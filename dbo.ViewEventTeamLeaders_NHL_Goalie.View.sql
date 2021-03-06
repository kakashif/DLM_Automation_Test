USE [SportsDB]
GO
/****** Object:  View [dbo].[ViewEventTeamLeaders_NHL_Goalie]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[ViewEventTeamLeaders_NHL_Goalie]
-- =============================================
-- Author:		John Titchener
-- Create date: 8/1/2012
-- Description:	Gets Goalie Team Leader statistics for NHL
-- =============================================
AS
	SELECT
 		teams.team_key,
 		tdn.full_name,
		persons.person_key,
		persons.id AS person_id,
		dn.last_name,
		dn.first_name,
		s.season_key,
		ss.sub_season_type,
		ds.goaltender_losses,
		--ds.goaltender_losses_overtime,
		ds.goaltender_wins
		--ds.goaltender_wins_overtime
	FROM
		 dbo.seasons AS s   WITH (NOLOCK) 
		 INNER JOIN dbo.sub_seasons AS ss  WITH (NOLOCK) 
			ON s.id = ss.season_id
			AND ss.sub_season_type = 'season-regular'
		 INNER JOIN dbo.stats  WITH (NOLOCK) 
			ON stat_coverage_id = ss.id
			AND stats.stat_coverage_type = 'sub_seasons'
			AND stats.stat_coverage_id = ss.id
			AND stats.stat_holder_type = 'persons'
			AND stats.stat_repository_type = 'ice_hockey_defensive_stats'
		 INNER JOIN dbo.ice_hockey_defensive_stats AS ds  WITH (NOLOCK) 
			ON ds.id = stats.stat_repository_id
			AND (ds.goaltender_losses IS NOT NULL and ds.goaltender_wins IS NOT NULL)
		 INNER JOIN dbo.persons  WITH (NOLOCK) 
			ON stats.stat_holder_id = persons.id
		 INNER JOIN dbo.display_names AS dn  WITH (NOLOCK) 
			ON  dn.entity_id = persons.id
			AND dn.entity_type = 'persons'
		 INNER JOIN dbo.teams  WITH (NOLOCK) 
			ON stats.stat_membership_id = teams.id
			AND teams.publisher_id = (SELECT MAX(id) FROM dbo.publishers WHERE publisher_key = 'sportsnetwork.com')
		 INNER JOIN dbo.team_phases AS tp  WITH (NOLOCK) 
			ON tp.team_id = teams.id
		INNER JOIN dbo.affiliations  AS la   WITH (NOLOCK) 
			ON tp.affiliation_id = la.id 
			AND la.publisher_id = teams.publisher_id 
			AND la.affiliation_type = 'league'
			and la.affiliation_key = 'l.nhl.com'
		 INNER JOIN dbo.display_names AS tdn  WITH (NOLOCK) 
			ON tdn.entity_id = teams.id
			AND tdn.entity_type = 'teams';

GO
