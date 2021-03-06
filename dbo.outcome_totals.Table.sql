USE [SportsDB]
GO
/****** Object:  Table [dbo].[outcome_totals]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[outcome_totals](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[standing_subgroup_id] [int] NOT NULL,
	[outcome_holder_type] [varchar](100) NULL,
	[outcome_holder_id] [int] NULL,
	[rank] [varchar](100) NULL,
	[wins] [varchar](100) NULL,
	[losses] [varchar](100) NULL,
	[ties] [varchar](100) NULL,
	[undecideds] [varchar](100) NULL,
	[winning_percentage] [varchar](100) NULL,
	[points_scored_for] [varchar](100) NULL,
	[points_scored_against] [varchar](100) NULL,
	[points_difference] [varchar](100) NULL,
	[standing_points] [varchar](100) NULL,
	[streak_type] [varchar](100) NULL,
	[streak_duration] [varchar](100) NULL,
	[streak_total] [varchar](100) NULL,
	[streak_start] [datetime] NULL,
	[streak_end] [datetime] NULL,
	[events_played] [int] NULL,
	[games_back] [varchar](100) NULL,
	[result_effect] [varchar](100) NULL,
	[sets_against] [varchar](100) NULL,
	[sets_for] [varchar](100) NULL,
	[losses_overtime] [int] NULL,
	[wins_overtime] [int] NULL,
 CONSTRAINT [PK__outcome_totals__1AD3FDA4] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
