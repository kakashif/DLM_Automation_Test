USE [SportsDB]
GO
/****** Object:  View [dbo].[View_USAT_DataModel_StandingsAll]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[View_USAT_DataModel_StandingsAll]
AS
SELECT DISTINCT 
                      TOP (100) PERCENT dbo.seasons.season_key, sa.affiliation_key, ul.league_name, dbo.affiliations.affiliation_type, dn_team.full_name, dbo.teams.team_key, dbo.teams.id as team_id, dn_team.first_name, 
                      dn_team.last_name, dn_team.abbreviation, dbo.sub_seasons.sub_season_type, dbo.standing_subgroups.alignment_scope, 
                      dbo.standing_subgroups.competition_scope, dbo.standing_subgroups.duration_scope, dbo.standings.standing_type, ca.affiliation_key AS conf, 
                      dn_ca.full_name AS ca_name, REPLACE(dn_div.full_name, ' Conference', '') AS div, da.affiliation_key AS division_key, da.affiliation_type AS division_type, dbo.outcome_totals.rank, 
                      dbo.outcome_totals.id AS outcome_totals_id,
                      (SELECT COUNT (*) FROM (SELECT TOP 10 event_outcome
                                                FROM dbo.[events] AS e
                                                    INNER JOIN dbo.participants_events AS pe ON e.id = pe.[event_id]
                                                    INNER JOIN dbo.events_sub_seasons AS ess ON ess.[event_id] = pe.[event_id]
                                                    INNER JOIN dbo.sub_seasons AS ss ON ess.sub_season_id = ss.id
                                                    INNER JOIN dbo.seasons AS s ON s.id = ss.season_id
                                                    INNER JOIN dbo.affiliations_events AS ae ON ae.[event_id] = pe.[event_id]
                                                    INNER JOIN dbo.affiliations AS a ON ae.affiliation_id = a.id
                                              WHERE pe.participant_id = dbo.teams.id
                                              AND pe.participant_type = 'teams'
                                              AND a.affiliation_key   = sa.affiliation_key
                                              AND e.start_date_time   <= GETDATE()
                                              AND s.season_key        = dbo.seasons.season_key
                                              AND ss.sub_season_type  = 'season-regular'
                                              AND e.event_status      = 'post-event'
                                              AND pe.event_outcome IN ('win', 'loss')
                                              ORDER BY e.start_date_time DESC) AS X WHERE X.event_outcome = 'win') AS L10,
                      (SELECT COUNT (*) FROM (SELECT TOP 10 event_outcome
                                                FROM dbo.[events] AS e
                                                    INNER JOIN dbo.participants_events AS pe ON e.id = pe.[event_id]
                                                    INNER JOIN dbo.events_sub_seasons AS ess ON ess.[event_id] = pe.[event_id]
                                                    INNER JOIN dbo.sub_seasons AS ss ON ess.sub_season_id = ss.id
                                                    INNER JOIN dbo.seasons AS s ON s.id = ss.season_id
                                                    INNER JOIN dbo.affiliations_events AS ae ON ae.[event_id] = pe.[event_id]
                                                    INNER JOIN dbo.affiliations AS a ON ae.affiliation_id = a.id
                                              WHERE pe.participant_id = dbo.teams.id
                                              AND pe.participant_type = 'teams'
                                              AND a.affiliation_key   = sa.affiliation_key
                                              AND e.start_date_time   <= GETDATE()
                                              AND s.season_key        = dbo.seasons.season_key
                                              AND ss.sub_season_type  = 'season-regular'
                                              AND e.event_status      = 'post-event'
                                              AND pe.event_outcome IN ('win', 'loss')
                                              ORDER BY e.start_date_time DESC) AS X WHERE X.event_outcome = 'win') AS L10_win,
                      (SELECT COUNT (*) FROM (SELECT TOP 10 event_outcome
                                                FROM dbo.[events] AS e
                                                    INNER JOIN dbo.participants_events AS pe ON e.id = pe.[event_id]
                                                    INNER JOIN dbo.events_sub_seasons AS ess ON ess.[event_id] = pe.[event_id]
                                                    INNER JOIN dbo.sub_seasons AS ss ON ess.sub_season_id = ss.id
                                                    INNER JOIN dbo.seasons AS s ON s.id = ss.season_id
                                                    INNER JOIN dbo.affiliations_events AS ae ON ae.[event_id] = pe.[event_id]
                                                    INNER JOIN dbo.affiliations AS a ON ae.affiliation_id = a.id
                                              WHERE pe.participant_id = dbo.teams.id
                                              AND pe.participant_type = 'teams'
                                              AND a.affiliation_key   = sa.affiliation_key
                                              AND e.start_date_time   <= GETDATE()
                                              AND s.season_key        = dbo.seasons.season_key
                                              AND ss.sub_season_type  = 'season-regular'
                                              AND e.event_status      = 'post-event'
                                              AND pe.event_outcome IN ('win', 'loss')
                                              ORDER BY e.start_date_time DESC) AS X WHERE X.event_outcome = 'loss') AS L10_loss,
                      dbo.outcome_totals.events_played, dbo.outcome_totals.wins, dbo.outcome_totals.losses, dbo.outcome_totals.ties, dbo.outcome_totals.winning_percentage, 
                      dbo.outcome_totals.games_back, dbo.outcome_totals.result_effect, dbo.outcome_totals.standing_points, dbo.outcome_totals.points_scored_against, 
                      dbo.outcome_totals.points_scored_for, dbo.outcome_totals.points_difference, dbo.outcome_totals.wins_overtime, dbo.outcome_totals.losses_overtime, 
                      dbo.outcome_totals.undecideds, dbo.outcome_totals.streak_duration, dbo.outcome_totals.streak_type, dbo.outcome_totals.streak_total, 
                      dbo.outcome_totals.streak_start, dbo.outcome_totals.streak_end
FROM         dbo.standings WITH (NOLOCK) INNER JOIN
                      dbo.standing_subgroups WITH (NOLOCK) ON dbo.standing_subgroups.standing_id = dbo.standings.id INNER JOIN
                      dbo.affiliations WITH (NOLOCK) ON dbo.affiliations.id = dbo.standing_subgroups.affiliation_id INNER JOIN
                      dbo.sub_seasons WITH (NOLOCK) ON dbo.sub_seasons.id = dbo.standings.sub_season_id INNER JOIN
                      dbo.seasons WITH (NOLOCK) ON dbo.seasons.id = dbo.sub_seasons.season_id INNER JOIN
                      dbo.publishers WITH (NOLOCK) ON dbo.seasons.publisher_id = dbo.publishers.id INNER JOIN
                      dbo.affiliations AS sa WITH (NOLOCK) ON dbo.standings.affiliation_id = sa.id INNER JOIN
                      dbo.USAT_leagues as ul WITH (NOLOCK) ON ul.league_id = sa.id INNER JOIN
                      dbo.affiliation_phases AS ap WITH (NOLOCK) ON ap.ancestor_affiliation_id = sa.id INNER JOIN
                      dbo.outcome_totals WITH (NOLOCK) ON dbo.outcome_totals.standing_subgroup_id = dbo.standing_subgroups.id INNER JOIN
                      dbo.teams WITH (NOLOCK) ON dbo.teams.id = dbo.outcome_totals.outcome_holder_id INNER JOIN
                      dbo.display_names AS dn_team WITH (NOLOCK) ON dn_team.entity_id = dbo.teams.id INNER JOIN
                      dbo.team_phases AS tp_con WITH (NOLOCK) ON dbo.teams.id = tp_con.team_id INNER JOIN
                      dbo.affiliations AS ca WITH (NOLOCK) ON ca.id = ap.affiliation_id AND tp_con.affiliation_id = ca.id INNER JOIN
                      dbo.display_names AS dn_ca WITH (NOLOCK) ON ca.id = dn_ca.entity_id AND dn_ca.entity_type = 'affiliations' INNER JOIN
                      dbo.affiliations AS da WITH (NOLOCK) ON da.id IN
                          (SELECT     affiliation_id
                            FROM          dbo.team_phases
                            WHERE      (team_id = dbo.teams.id)) INNER JOIN
                      dbo.display_names AS dn_div WITH (NOLOCK) ON da.id = dn_div.entity_id AND dn_div.entity_type = 'affiliations'
WHERE     (sa.affiliation_key IN ('l.nba.com', 'l.nfl.com', 'l.mlb.com', 'l.nhl.com', 'l.wnba.com', 'l.mlsnet.com')) AND (dn_team.entity_type = 'teams') AND 
                      (ca.affiliation_type = 'conference') AND (da.affiliation_type = 'division') AND (dbo.publishers.publisher_key = 'sportsnetwork.com') OR
                      (dn_team.entity_type = 'teams') AND (da.affiliation_type = 'division') AND (dbo.teams.team_key LIKE 'l.ncaa.org.mbasket%' OR
                      dbo.teams.team_key LIKE 'l.ncaa.org.mfoot%') AND (dbo.standing_subgroups.competition_scope <> 'all')
ORDER BY dbo.seasons.season_key, sa.affiliation_key, dn_team.full_name

GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[39] 4[33] 2[12] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1[50] 4[25] 3) )"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = -192
         Left = 0
      End
      Begin Tables = 
         Begin Table = "standings"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 125
               Right = 198
            End
            DisplayFlags = 280
            TopColumn = 2
         End
         Begin Table = "standing_subgroups"
            Begin Extent = 
               Top = 6
               Left = 236
               Bottom = 125
               Right = 428
            End
            DisplayFlags = 280
            TopColumn = 5
         End
         Begin Table = "affiliations"
            Begin Extent = 
               Top = 6
               Left = 466
               Bottom = 125
               Right = 627
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "sub_seasons"
            Begin Extent = 
               Top = 6
               Left = 665
               Bottom = 125
               Right = 839
            End
            DisplayFlags = 280
            TopColumn = 2
         End
         Begin Table = "seasons"
            Begin Extent = 
               Top = 6
               Left = 877
               Bottom = 125
               Right = 1043
            End
            DisplayFlags = 280
            TopColumn = 2
         End
         Begin Table = "publishers"
            Begin Extent = 
               Top = 250
               Left = 838
               Bottom = 354
               Right = 1002
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "sa"
            Begin Extent = 
               Top = 126
               Left = 38
               Bottom = 245
               Right = 199
            End
            ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'View_USAT_DataModel_StandingsAll'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane2', @value=N'DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ap"
            Begin Extent = 
               Top = 126
               Left = 237
               Bottom = 245
               Right = 432
            End
            DisplayFlags = 280
            TopColumn = 4
         End
         Begin Table = "outcome_totals"
            Begin Extent = 
               Top = 126
               Left = 470
               Bottom = 245
               Right = 667
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "teams"
            Begin Extent = 
               Top = 126
               Left = 705
               Bottom = 245
               Right = 865
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "dn_team"
            Begin Extent = 
               Top = 126
               Left = 903
               Bottom = 245
               Right = 1063
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "tp_con"
            Begin Extent = 
               Top = 246
               Left = 38
               Bottom = 365
               Right = 204
            End
            DisplayFlags = 280
            TopColumn = 5
         End
         Begin Table = "ca"
            Begin Extent = 
               Top = 246
               Left = 242
               Bottom = 365
               Right = 403
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "dn_ca"
            Begin Extent = 
               Top = 354
               Left = 838
               Bottom = 473
               Right = 998
            End
            DisplayFlags = 280
            TopColumn = 9
         End
         Begin Table = "da"
            Begin Extent = 
               Top = 246
               Left = 441
               Bottom = 365
               Right = 602
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "dn_div"
            Begin Extent = 
               Top = 246
               Left = 640
               Bottom = 365
               Right = 800
            End
            DisplayFlags = 280
            TopColumn = 7
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 34
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 2490
         Alias = 1425
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'View_USAT_DataModel_StandingsAll'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=2 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'View_USAT_DataModel_StandingsAll'
GO
