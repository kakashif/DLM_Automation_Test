USE [SportsDB]
GO
/****** Object:  Table [dbo].[motor_racing_race_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[motor_racing_race_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[time_behind_leader] [varchar](100) NULL,
	[laps_behind_leader] [varchar](100) NULL,
	[time_ahead_follower] [varchar](100) NULL,
	[laps_ahead_follower] [varchar](100) NULL,
	[time] [varchar](100) NULL,
	[points] [varchar](100) NULL,
	[points_rookie] [varchar](100) NULL,
	[bonus] [varchar](100) NULL,
	[laps_completed] [varchar](100) NULL,
	[laps_leading_total] [varchar](100) NULL,
	[distance_leading] [varchar](100) NULL,
	[distance_completed] [varchar](100) NULL,
	[distance_units] [varchar](40) NULL,
	[speed_average] [varchar](40) NULL,
	[speed_units] [varchar](40) NULL,
	[status] [varchar](40) NULL,
	[finishes_top_5] [varchar](40) NULL,
	[finishes_top_10] [varchar](40) NULL,
	[starts] [varchar](40) NULL,
	[finishes] [varchar](40) NULL,
	[non_finishes] [varchar](40) NULL,
	[wins] [varchar](40) NULL,
	[races_leading] [varchar](40) NULL,
	[money] [varchar](40) NULL,
	[money_units] [varchar](40) NULL,
	[leads_total] [varchar](40) NULL,
 CONSTRAINT [PK__motor_racing_rac__151B244E] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
