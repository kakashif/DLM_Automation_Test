USE [SportsDB]
GO
/****** Object:  Table [dbo].[ice_hockey_time_on_ice_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ice_hockey_time_on_ice_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[player_count] [int] NULL,
	[player_count_opposing] [int] NULL,
	[shifts] [int] NULL,
	[time_total] [varchar](40) NULL,
	[time_power_play] [varchar](40) NULL,
	[time_short_handed] [varchar](40) NULL,
	[time_even_strength] [varchar](40) NULL,
	[time_empty_net] [varchar](40) NULL,
	[time_power_play_empty_net] [varchar](40) NULL,
	[time_short_handed_empty_net] [varchar](40) NULL,
	[time_even_strength_empty_net] [varchar](40) NULL,
	[time_average_per_shift] [varchar](40) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
