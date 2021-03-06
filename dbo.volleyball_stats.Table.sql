USE [SportsDB]
GO
/****** Object:  Table [dbo].[volleyball_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[volleyball_stats](
	[id] [int] NOT NULL,
	[service_attempts] [int] NULL,
	[service_successes] [int] NULL,
	[service_faults] [int] NULL,
	[service_aces] [int] NULL,
	[service_fastest] [int] NULL,
	[attack_attempts] [int] NULL,
	[attack_successes] [int] NULL,
	[block_attempts] [int] NULL,
	[block_successes] [int] NULL,
	[dig_attempts] [int] NULL,
	[dig_successes] [int] NULL,
	[spike_attempts] [int] NULL,
	[spike_successes] [int] NULL,
	[points] [int] NULL,
	[point_attempts] [int] NULL,
	[opponent_errors] [int] NULL,
 CONSTRAINT [PK_volleyball_stats] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
