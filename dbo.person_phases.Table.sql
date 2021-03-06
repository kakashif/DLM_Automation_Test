USE [SportsDB]
GO
/****** Object:  Table [dbo].[person_phases]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[person_phases](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[person_id] [int] NOT NULL,
	[membership_type] [varchar](40) NOT NULL,
	[membership_id] [int] NOT NULL,
	[role_id] [int] NULL,
	[role_status] [varchar](40) NULL,
	[phase_status] [varchar](40) NULL,
	[uniform_number] [varchar](20) NULL,
	[regular_position_id] [int] NULL,
	[regular_position_depth] [varchar](40) NULL,
	[height] [varchar](100) NULL,
	[weight] [varchar](100) NULL,
	[start_date_time] [datetime] NULL,
	[start_season_id] [int] NULL,
	[end_date_time] [datetime] NULL,
	[end_season_id] [int] NULL,
	[entry_reason] [varchar](40) NULL,
	[exit_reason] [varchar](40) NULL,
	[selection_level] [int] NULL,
	[selection_sublevel] [int] NULL,
	[selection_overall] [int] NULL,
	[duration] [varchar](32) NULL,
	[phase_type] [varchar](40) NULL,
	[subphase_type] [varchar](40) NULL,
 CONSTRAINT [PK__person_phases__245D67DE] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
